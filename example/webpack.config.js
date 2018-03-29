const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const webpack = require('webpack');

module.exports = {
  entry: path.resolve(__dirname, 'src/index.js'),
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.js'
  },
  resolve: {
    modules: [
      path.resolve(__dirname, 'node_modules'),
      path.resolve(__dirname, 'bower_components')
    ]
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.html$/,
        use: [
          {
            loader: 'babel-loader'
          },
          'polymer-webpack-loader'
        ]
      },
      {
        test: /\.elm$/,
        use: [
          {
            loader: 'elm-hot-loader'
          },
          {
            loader: 'elm-webpack-loader',
            options: {
              debug: true,
              warn: false
            }
          }
        ]
      },
      {
        test: /\.(gif|png|jpe?g|svg)$/i,
        use: [
          'file-loader?name=[name].[ext]&outputPath=/images/',
          {
            loader: 'image-webpack-loader',
            options: {
              bypassOnDebug: true
            }
          }
        ]
      },
      {
        test: /\.scss/,
        use: [ 'style-loader', 'css-loader', 'sass-loader' ]
      }
    ]
  },
  devServer: {
    compress: true,
    hot: true,
    contentBase: path.resolve(__dirname, 'dist'),
    stats: 'errors-only',
    host: '::',
    public: '[::1]:8888',
    port: 8888
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './src/index.ejs',
      inject: false
    }),
    new CopyWebpackPlugin([{
      from: path.resolve(__dirname, 'bower_components/webcomponentsjs/*.js'),
      to: 'bower_components/webcomponentsjs/[name].[ext]'
    }]),
    new webpack.NamedModulesPlugin(),
    new webpack.HotModuleReplacementPlugin(),
    new webpack.NoEmitOnErrorsPlugin()
  ]
};
