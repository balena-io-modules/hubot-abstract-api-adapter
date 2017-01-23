# Project description

This project has been created to form a core from which I can develop Hubot adapters.  It was
created following the discovery that the examples provided by GitHub in their Hubot documentation
do not work with the latest version.
This is intended primarily as a internal use project, but with the hope of making it as externally
useful as is reasonable along the way.

## Documentation

Where possible, documentation is going to happen in line with the code.  The exceptions to this are below.

### package.json

* `name` must be replaced
* `version` should be managed by npm version
* `description` must be replaced
* `main` must be tweaked to reflect your adapter's name
* `repository.url` must be replaced
* `keywords` should be extended
* `author` must be replaced
* `license` could be replaced
* `bugs.url` must be replaced
* `dependencies` should be managed by npm install --save
* `peerDependancies` is unlikely to need work
* `devDependances` should be trimmed, a few adapters provided for example code
* `homepage` must be replaced

# A [Hubot](https://github.com/github/hubot) adapter

This adapter 'receives' a simple message once a second.

## Compatibility

## Installing

`npm install --save hubot-base-adapter`

## Configuring

No configuration options exist
