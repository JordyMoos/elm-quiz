const webpack = require('webpack');
const merge = require('webpack-merge');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const HTMLWebpackPlugin = require('html-webpack-plugin');
const WebpackPwaManifest = require('webpack-pwa-manifest');
const path = require('path');
const appConfig = require('./config.json');

const TARGET_ENV = process.env.npm_lifecycle_event === 'prod'
    ? 'production'
    : 'development';

const common = {
    entry: './src/index.js',
    output: {
        path: path.join(__dirname, "dist"),
        // add hash when building for production
        filename: 'index.js'
    },
    externals: {
        'Config': JSON.stringify(appConfig)
    },
    plugins: [
        new HTMLWebpackPlugin({
            // using .ejs prevents other loaders causing errors
            template: 'src/index.ejs',
            // inject details of output file at end of body
            inject: 'body',
        }),

        new CopyWebpackPlugin([{
            from: path.resolve(__dirname, 'bower_components/webcomponentsjs/*.js'),
            to: 'bower_components/webcomponentsjs/[name].[ext]'
        }, {
            from: path.resolve(__dirname, 'bower_components/web-animations-js/*.js'),
            to: 'bower_components/web-animations-js/[name].[ext]'
        }, {
            from: path.resolve(__dirname, 'src/static/'),
            to: 'static/'
        }])
    ],
    resolve: {
        modules: [
            path.join(__dirname, "src"),
            "node_modules"
        ],
        extensions: ['.js', '.elm', '.scss', '.png']
    },
    module: {
        rules: [
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
                test: /\.scss$/,
                exclude: [
                    /elm-stuff/, /node_modules/
                ],
                loaders: ["style-loader", "css-loader", "sass-loader"]
            },
            {
                test: /\.css$/,
                exclude: [
                    /elm-stuff/, /node_modules/
                ],
                loaders: ["style-loader", "css-loader"]
            },
            {
                test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/,
                exclude: [
                    /elm-stuff/, /node_modules/
                ],
                loader: "url-loader",
                options: {
                    limit: 10000,
                    mimetype: "application/font-woff"
                }
            },
            {
                test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
                exclude: [
                    /elm-stuff/, /node_modules/
                ],
                loader: "url-loader"
            },
            {
                test: /\.(jpe?g|png|gif|svg)$/i,
                loader: 'url-loader'
            }
        ]
    }
};

if (TARGET_ENV === 'development') {
    console.log('Building for dev...');
    module.exports = merge(common, {
        plugins: [
            // Suggested for hot-loading
            new webpack.NamedModulesPlugin(),
            // Prevents compilation errors causing the hot loader to lose state
            new webpack.NoEmitOnErrorsPlugin()
        ],
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [
                        /elm-stuff/, /node_modules/
                    ],
                    use: [
                        {
                            loader: "elm-hot-loader"
                        }, {
                            loader: "elm-webpack-loader",
                            // add Elm's debug overlay to output
                            options: {
                                debug: true
                            }
                        }
                    ]
                },
                {
                    test: /\.js$/,
                    exclude: [
                      /node_modules/,
                      /bower_components/
                    ],
                    use: {
                        loader: 'babel-loader',
                        options: {
                            // env: automatically determines the Babel plugins you need based on your supported environments
                            presets: ['env']
                        }
                    }
                }
            ]
        },
        devServer: {
            inline: true,
            stats: 'errors-only',
            contentBase: path.resolve(__dirname, 'dist'),
        }
    });
}

if (TARGET_ENV === 'production') {
    console.log('Building for prod...');
    module.exports = merge(common, {
        plugins: [
            new webpack.optimize.UglifyJsPlugin(),
        ],
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [
                        /elm-stuff/, /node_modules/
                    ],
                    use: [
                        {
                            loader: "elm-webpack-loader",
                        }
                    ]
                },
                {
                    test: /\.js$/,
                    // exclude: /node_modules/,
                    use: {
                        loader: 'babel-loader',
                        options: {
                            // env: automatically determines the Babel plugins you need based on your supported environments
                            presets: ['env']
                        }
                    }
                }
            ]
        }
    });
}
