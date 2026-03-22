import commonjs from "@rollup/plugin-commonjs";
import nodeResolve from "@rollup/plugin-node-resolve";
import terser from "@rollup/plugin-terser";
import typescript from "@rollup/plugin-typescript";
import path from "node:path";
import url from "node:url";

const isWatching = !!process.env.ROLLUP_WATCH;
const sdPlugin = "com.maxime-janvier.premiere-ecoute-streamer.sdPlugin";
const sdPluginViewer = "com.maxime-janvier.premiere-ecoute-viewer.sdPlugin";

function makeConfig(input, outputDir) {
	return {
		input,
		output: {
			file: `${outputDir}/bin/plugin.js`,
			sourcemap: isWatching,
			sourcemapPathTransform: (relativeSourcePath, sourcemapPath) => {
				return url.pathToFileURL(path.resolve(path.dirname(sourcemapPath), relativeSourcePath)).href;
			}
		},
		plugins: [
			{
				name: "watch-externals",
				buildStart: function () {
					this.addWatchFile(`${outputDir}/manifest.json`);
				},
			},
			typescript({
				mapRoot: isWatching ? "./" : undefined
			}),
			nodeResolve({
				browser: false,
				exportConditions: ["node"],
				preferBuiltins: true
			}),
			commonjs(),
			!isWatching && terser(),
			{
				name: "emit-module-package-file",
				generateBundle() {
					this.emitFile({ fileName: "package.json", source: `{ "type": "module" }`, type: "asset" });
				}
			}
		]
	};
}

export default [
	makeConfig("src/plugin-streamer.ts", sdPlugin),
	makeConfig("src/plugin-viewer.ts", sdPluginViewer),
];
