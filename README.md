# Tr33 Control

A web interface to control effects on leds strips. It sends commands to an ESP32 board that controls the leds. The corresponding firmware for the ESP32 can be found [here](https://github.com/xHain-hackspace/tr33). 

This app leverages phoenix channels to sync the state between all connected browsers, so everybody sees the same state. The dynamic forms are all rendered in the backend and pushed via a live_html channel to the clients. It is an attempt to create a dynamic web app with almost no javascript.

## Installation

The main dependency is `elixir`. There are many ways to install it. See the [elixir install instructions](https://elixir-lang.org/install.html). 
You also need a version of `npm` installed to get the frontend assets. 

There is `Makefile` with the most common commands. 

```
make init
```

Will install all required dependencies.


## Configuration

The file `dev/tr33_control/config/config.exs` contains some configuration you might want to change. 

* The `targets` contain all supported led_structures. The `host` of a target reprepsents one ESP32 that is reachable via network. It can be a domain or IP Address.
* The `active_targets` is a white list of targets that should be active in this installation.

## Running the UI

```
make console
```

Should start the web interface on `localhost:4000` and sync the commands to all ESP32s. 
