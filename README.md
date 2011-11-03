# Theme Editor

A Sinatra web app for editing Textmate Themes. Uses Backbone.js.

## Setup

By default, the app loads theme files from anywhere within ~/Library/Application Support/Sublime Text 2/Packages.

Change the `file_root` setting in themes.rb to look elsewhere.

## Run

Run from a Rack server such as [POW](http://pow.cx/) or [Shotgun](https://github.com/rtomayko/shotgun).

Install dependencies with [Bundler](http://gembundler.com/) (do `gem install bundler` if necessary):

    bundle install

Install shotgun and load rackup file:

    gem install shotgun
    shotgun config.ru

You should be up and running at [http://localhost:9393](http://localhost:9393)

## IMPORTANT! Disclaimer

**Please, please please don't trust me with your theme files!** The app overwrites the .tmTheme file with every alteration and does not prompt you to save.

Make a backup of all .tmTheme files before altering them with the app.

