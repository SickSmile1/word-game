import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { WebSocketServer } from 'ws';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const WEB_DIR = path.resolve(__dirname, '../../export/web');
const HTTP_PORT = 8085;
const WS_PORT = 8086;

function startStaticServer() {
  const server = http.createServer((req, res) => {
    let filePath = path.join(WEB_DIR, req.url === '/' ? 'index.html' : req.url);
    if (!fs.existsSync(filePath)) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    const ext = path.extname(filePath);
    const contentType = {
      '.html': 'text/html',
      '.js': 'application/javascript',
      '.wasm': 'application/wasm',
      '.pck': 'application/octet-stream',
      '.png': 'image/png',
    }[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    fs.createReadStream(filePath).pipe(res);
  });

  return new Promise((resolve) => {
    server.listen(HTTP_PORT, () => {
      console.log(`Static web server running at http://localhost:${HTTP_PORT}`);
      resolve(server);
    });
  });
}

function startSignalingServer() {
  const rooms = new Map();
  const wss = new WebSocketServer({ port: WS_PORT });

  wss.on('connection', (ws) => {
    let currentRoom = null;

    ws.on('message', (raw) => {
      const text = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = JSON.parse(text);
      console.log('[Signaling Server RECV]', msg);

      if (msg.type === 'create') {
        currentRoom = String(Math.floor(100000 + Math.random() * 900000));
        rooms.set(currentRoom, new Set([ws]));
        console.log(`[Signaling Server] Room ${currentRoom} created`);
        ws.send(JSON.stringify({ type: 'created', room: currentRoom, slot: 0 }));
      } else if (msg.type === 'join') {
        currentRoom = String(msg.room);
        const roomSet = rooms.get(currentRoom);
        if (roomSet && roomSet.size < 2) {
          roomSet.add(ws);
          console.log(`[Signaling Server] Guest joined room ${currentRoom}`);
          ws.send(JSON.stringify({ type: 'joined', room: currentRoom, slot: roomSet.size - 1 }));
        } else {
          console.log(`[Signaling Server] Join room ${currentRoom} failed`);
          ws.send(JSON.stringify({ type: 'error', reason: roomSet ? 'room_full' : 'not_found' }));
        }
      } else if (msg.type === 'session' || msg.type === 'candidate') {
        const roomSet = rooms.get(currentRoom);
        if (roomSet) {
          for (const client of roomSet) {
            if (client !== ws && client.readyState === 1) {
              console.log(`[Signaling Server] Relay ${msg.type} (${msg.subtype || ''}) to peer`);
              client.send(JSON.stringify(msg));
            }
          }
        }
      }
    });

    ws.on('close', () => {
      if (currentRoom && rooms.has(currentRoom)) {
        rooms.get(currentRoom).delete(ws);
      }
    });
  });

  console.log(`Local signaling server running at ws://localhost:${WS_PORT}`);
  return wss;
}

async function runTest() {
  const httpServer = await startStaticServer();
  const wss = startSignalingServer();

  const browser = await chromium.launch({
    headless: true,
  });

  try {
    console.log('\n=== Launching Host Browser ===');
    const hostContext = await browser.newContext({ viewport: { width: 1080, height: 1920 } });
    const hostPage = await hostContext.newPage();

    let createdRoomCode = null;
    let p2pHostConnected = false;
    let p2pGuestConnected = false;

    hostPage.on('console', (msg) => {
      const text = msg.text();
      console.log(`[Host Console] ${text}`);
      const match = text.match(/\[Net\] Room (\d{6}) created \(slot 0\)/);
      if (match) {
        createdRoomCode = match[1];
        console.log(`\n🎉 HOST CREATED ROOM CODE: ${createdRoomCode} 🎉\n`);
      }
      if (text.includes('[Net] WebRTC connection state changed: 2')) {
        p2pHostConnected = true;
      }
    });

    await hostPage.goto(`http://localhost:${HTTP_PORT}/index.html`);
    await hostPage.evaluate((wsUrl) => {
      window.SCRABBLE_SIGNALING_URL = wsUrl;
    }, `ws://localhost:${WS_PORT}`);

    await hostPage.waitForSelector('#canvas');
    await hostPage.waitForTimeout(3000);

    // Click START button at (540, 807)
    console.log('Host: Clicking START button (540, 807)...');
    await hostPage.mouse.click(540, 807);
    await hostPage.waitForTimeout(1000);

    // Click ONLINE button at (540, 860)
    console.log('Host: Clicking ONLINE button (540, 860)...');
    await hostPage.mouse.click(540, 860);
    await hostPage.waitForTimeout(1500);

    // Click CREATE ROOM button at (398, 816)
    console.log('Host: Clicking CREATE ROOM button (398, 816)...');
    await hostPage.mouse.click(398, 816);

    // Wait up to 10s for room code creation
    for (let i = 0; i < 20; i++) {
      if (createdRoomCode) break;
      await hostPage.waitForTimeout(500);
    }

    if (!createdRoomCode) {
      console.error('FAILED: Host could not create room!');
      await hostPage.screenshot({ path: 'host_failed.png' });
      process.exit(1);
    }

    console.log('\n=== Launching Guest Browser ===');
    const guestContext = await browser.newContext({ viewport: { width: 1080, height: 1920 } });
    const guestPage = await guestContext.newPage();

    guestPage.on('console', (msg) => {
      const text = msg.text();
      console.log(`[Guest Console] ${text}`);
      if (text.includes('[Net] WebRTC connection state changed: 2')) {
        p2pGuestConnected = true;
      }
    });

    await guestPage.goto(`http://localhost:${HTTP_PORT}/index.html`);
    await guestPage.evaluate((wsUrl) => {
      window.SCRABBLE_SIGNALING_URL = wsUrl;
    }, `ws://localhost:${WS_PORT}`);

    await guestPage.waitForSelector('#canvas');
    await guestPage.waitForTimeout(3000);

    // Click START (540, 807)
    console.log('Guest: Clicking START button (540, 807)...');
    await guestPage.mouse.click(540, 807);
    await guestPage.waitForTimeout(1000);

    // Click ONLINE (540, 860)
    console.log('Guest: Clicking ONLINE button (540, 860)...');
    await guestPage.mouse.click(540, 860);
    await guestPage.waitForTimeout(1500);

    // Click JOIN ROOM button at (682, 816)
    console.log('Guest: Clicking JOIN ROOM button (682, 816)...');
    await guestPage.mouse.click(682, 816);
    await guestPage.waitForTimeout(1000);

    // Click input box (540, 880) and type Room Code
    console.log(`Guest: Typing room code "${createdRoomCode}"...`);
    await guestPage.mouse.click(540, 880);
    await guestPage.keyboard.type(createdRoomCode);
    await guestPage.keyboard.press('Enter');

    console.log('Waiting for WebRTC P2P connection to establish between Host & Guest...');
    for (let i = 0; i < 30; i++) {
      if (p2pHostConnected && p2pGuestConnected) break;
      await guestPage.waitForTimeout(500);
    }

    await hostPage.screenshot({ path: 'host_final.png' });
    await guestPage.screenshot({ path: 'guest_final.png' });

    if (p2pHostConnected && p2pGuestConnected) {
      console.log('\n✅ E2E TEST PASSED: WebRTC P2P multiplayer room creation and guest connection successful! ✅\n');
    } else {
      console.log(`\nP2P Connection state — Host P2P: ${p2pHostConnected}, Guest P2P: ${p2pGuestConnected}`);
    }

  } finally {
    await browser.close();
    wss.close();
    httpServer.close();
  }
}

runTest().catch((err) => {
  console.error('Test error:', err);
  process.exit(1);
});
