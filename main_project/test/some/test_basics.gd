extends GutTest

func test_lie() -> void:
	assert_eq(false, "cannot be false")

func test_truth() -> void:
	assert_eq("f".contains("f"), true, "cannot be false")
