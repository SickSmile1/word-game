extends GutTest

const RackDisplay = preload("res://scripts/ui/RackDisplay.gd")


func test_exchange_indices_tracking():
	var rack = autofree(RackDisplay.new())
	rack._build_slots()

	# Verify initial state
	assert_eq(rack.get_exchange_indices().size(), 0, "Should start with no exchange indices")

	# Toggle exchange mode
	rack.set_exchange_mode(true)
	assert_true(rack._exchange_mode, "Should be in exchange mode")

	# Toggle first index
	rack.toggle_exchange_index(0)
	assert_true(rack.get_exchange_indices().has(0), "Index 0 should be selected")
	assert_eq(rack.get_exchange_indices().size(), 1, "Should have 1 selected index")

	# Toggle second index
	rack.toggle_exchange_index(1)
	assert_true(rack.get_exchange_indices().has(1), "Index 1 should be selected")
	assert_eq(rack.get_exchange_indices().size(), 2, "Should have 2 selected indices")

	# Deselect first index
	rack.toggle_exchange_index(0)
	assert_false(rack.get_exchange_indices().has(0), "Index 0 should be deselected")
	assert_eq(rack.get_exchange_indices().size(), 1, "Should have 1 selected index")


func test_exchange_mode_clears_indices():
	var rack = autofree(RackDisplay.new())
	rack._build_slots()

	rack.set_exchange_mode(true)
	rack.toggle_exchange_index(0)
	rack.toggle_exchange_index(1)

	assert_eq(rack.get_exchange_indices().size(), 2, "Should have 2 selected")

	# Disable exchange mode
	rack.set_exchange_mode(false)
	assert_eq(
		rack.get_exchange_indices().size(), 0, "Should clear indices when disabling exchange mode"
	)


func test_exchange_mode_toggle():
	var rack = autofree(RackDisplay.new())
	rack._build_slots()

	# Start not in exchange mode
	assert_false(rack._exchange_mode)

	# Enter exchange mode
	rack.set_exchange_mode(true)
	assert_true(rack._exchange_mode)

	# Exit exchange mode
	rack.set_exchange_mode(false)
	assert_false(rack._exchange_mode)
