const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

class InlineJSPlugin {
  apply(compiler) {
    compiler.hooks.compilation.tap('InlineJSPlugin', (compilation) => {
      HtmlWebpackPlugin.getHooks(compilation).beforeEmit.tapAsync(
        'InlineJSPlugin',
        (data, cb) => {
          // Get the JS content
          const jsAsset = compilation.assets['viewer.js'];
          if (jsAsset) {
            const jsContent = jsAsset.source();
            // Add inline script before closing body tag
            data.html = data.html.replace(
              '</body>',
              `<script>${jsContent}</script></body>`
            );
            // Remove the separate JS file
            delete compilation.assets['viewer.js'];
            delete compilation.assets['viewer.js.LICENSE.txt'];
          }
          cb(null, data);
        }
      );
    });
  }
}

module.exports = (env, argv) => {
  const isProduction = argv.mode === 'production';
  
  return {
    entry: './src/viewer.js',
    output: {
      path: path.resolve(__dirname, 'dist'),
      filename: 'viewer.js',
      clean: true
    },
    optimization: {
      splitChunks: false, // Disable code splitting to create single file
      minimize: false, // Disable JS minification
    },
    module: {
      rules: [
        {
          test: /\.(js|jsx)$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: ['@babel/preset-env', '@babel/preset-react']
            }
          }
        },
        {
          test: /\.css$/i,
          use: ['style-loader', 'css-loader']
        }
      ]
    },
    plugins: [
      new HtmlWebpackPlugin({
        template: './public/viewer.html',
        filename: 'viewer.html', // Keep viewer.html for both dev and production
        inject: isProduction ? false : 'body', // In dev, inject normally; in prod, don't inject
        minify: false // Keep HTML readable
      }),
      ...(isProduction ? [new InlineJSPlugin()] : []) // Only inline in production
    ],
    resolve: {
      extensions: ['.js', '.jsx']
    },
    devServer: {
      static: './dist',
      port: 8080,
      hot: true,
      https: true // Required for Twitch extensions
    }
  };
};