local os = (require"love.system").getOS()

return {
	DEBUG_MODE = true,

	title = "Friday Night Funkin' Löve",
	file = "FNF-LOVE",
	icon = "art/icon.png",
	version = "1.0.1-dev",
	package = "fr.stilic.fnflove",
	width = 1280,
	height = 720,

	adaptableWidth = os == "Android" or os == "iOS",

	FPS = 60,
	vSync = true,
	company = "Stilic",

	flags = {
		loxelInitWindow = true,
		checkForUpdates = false,

		loxelInitialAutoPause = true,
		loxelInitialParallelUpdate = true,
		loxelInitialAsyncInput = false,

		loxelForceRenderCameraComplex = false,
		loxelDisableRenderCameraComplex = false,
		loxelDisableScissorOnRenderCameraSimple = false,
		loxelDefaultClipCamera = true,

		jitFFI = false,

		imageAlphaBleed = true,
		imageQuality = 1,
		imageBlurSamples = 0,

		animateAtlasRenderCanvas = true,
		animateAtlasQuality = 2,
	}
}
