const Elm = require('./elm/Main.elm');

import Config from 'Config';
import './styles.scss';
import '../bower_components/paper-styles/color.html';
import '../bower_components/paper-styles/paper-styles.html';
import '../bower_components/paper-button/paper-button.html';
import '../bower_components/app-layout/app-layout.html';
import '../bower_components/iron-icons/iron-icons.html';
import '../bower_components/paper-icon-button/paper-icon-button.html';
import '../bower_components/paper-card/paper-card.html';
import '../bower_components/paper-item/paper-icon-item.html';
import '../bower_components/paper-item/paper-item.html';
import '../bower_components/iron-icons/av-icons.html';
import '../bower_components/paper-fab/paper-fab.html';


let app = Elm.Main.fullscreen(Config);
