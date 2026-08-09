extends GutTest

const LobbyScene := preload("res://scenes/lobby/Lobby.tscn")


func test_lobby_scene_loads():
	assert_not_null(LobbyScene, "Lobby.tscn must exist (fixes the dead Online button link)")


func test_lobby_script_methods():
	var script := load("res://scripts/ui/Lobby.gd")
	assert_not_null(script, "Lobby.gd must exist")


func test_lobby_instantiates():
	var lobby: Node = LobbyScene.instantiate()
	add_child_autofree(lobby)
	await get_tree().process_frame
	assert_not_null(lobby.get_node_or_null("%CreateButton"), "CreateButton must exist")
	assert_not_null(lobby.get_node_or_null("%JoinButton"), "JoinButton must exist")
	assert_not_null(lobby.get_node_or_null("%RoomLabel"), "RoomLabel must exist")
	assert_not_null(lobby.get_node_or_null("%StatusLabel"), "StatusLabel must exist")
