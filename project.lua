local os = (require"love.system").getOS()

return {
	DEBUG_MODE = true,

	title = "Friday Night Funkin' Löve",
	file = "FNF-LOVE",
	icon = "art/icon.png",
	version = "1.0.1-dev",
	package = "com.stilic.fnflove",
	width = 1280,
	height = 720,

	adaptableWidth = os == "Android" or os == "iOS",

	FPS = 60,
	vSync = true,
	company = "Stilic",

	flags = {
		checkForUpdates = false,

		loxelInitialAutoPause = true,
		loxelInitialParallelUpdate = true,
		loxelInitialAsyncInput = false,

		loxelForceRenderCameraComplex = false,
		loxelDisableRenderCameraComplex = false,
		loxelDisableScissorOnRenderCameraSimple = false,
		loxelDefaultClipCamera = true
	}
}