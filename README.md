# Tr33 Control

A web interface to control effects on leds strips. It sends commands to an ESP32 board that controls the leds. The corresponding firmware for the ESP32 can be found [here](https://github.com/xHain-hackspace/tr33). The commands can be send via UDP and UART.

This app leverages phoenix channels to sync the state between all connected browsers, so everybody sees the same state. The dynamic forms are all rendered in the backend and pushed via a live_html channel to the clients. It is an attempt to create a dynamic web app with almost no javascript.

# Bugs/features
* mapped shape/slope/... broken? (Tr33 only, strip index 0)
* gravity not working
* white color palette
* mapped ping_pong
* fix UART in general
* tr33 UART not working for some reason, might be the cable
* order branch and trunk indices/PINs
* improve mobile support
* Idea for testing: create some sequence that uses all features
* create header button style
* movement_type (or render option) circle (for trommel and others)
* twang + joystick
* mapped position to 16bit
* properly set max value for modifiers
* measure FPS (looks good)
* replace sequence with phash2 of all commands
* movement_type: steps, steps_transition
* disable button for Commands
* resync button
* Sync time between ESPs
* Sync random seed betwenn ESPs
* use some effects from WLED
* effects relative to strip height/prixel count
  * gravity height relative to strip length
* fix add ball for gravity
* modifier for palette 
* random walk for tr33
* diffusion (lava lamp) effect
* move slope, or render in general: color shift effect (or similar) instead of solid color 
  * slope -> change/shift color effect 
* bug in mapped slope: use perpendicular distance instead of y distance
* gravity
* beat detection
* option to configure fade vs set in effects
* generally more effects like kaleidoscope
* mapped 2D bouncing ball
* softer sparkle

## done
* select command when last is deleted 
* multiple instances of rain/sparkle/etc
* wolken index
* rainbow_width and size @ 0 (Tr33 only, strip index 0)
* Wolken -> one structure, multiple strip indexes
* color palettes (steal some from wled)
* using cursors for UI selects
* ping pong period @ 0 crashes
* ping pong count
* initial preset load fails completely
* delete all modifiers when toggled off
* add pb option to define max value
* resync should reset all target commands? (wont do)
* remember targets on command change
* render position max to 65... (custom params on sliders)
* debounce issues when slider is at the bottom
  * move rate limiting to listeners
* modifier
* Tr33 rainbow broken at trunk/branches crossing
* regularly send squence number from ESPs for eventual consistency
* Tr33: fix extended LedStructure functions
* single color always overwrites (Tr33 only, strip index 0)
* fix wifi status overlay
* Strip index -> 0 == all
* per command palettes
* fix max validations => inputs/data as proper data structures?
* render effect: position 2 bytes
* add more palettes
* strip index select does not work
* send sync request on boot
* discard live view sessions on restart/reconnect
* Move modifiers to ESP
  * reverse sawtooth in firmware
* twang
* joystick plug and play
* move up/down -> no update
* bug: change type when moving command
* type select not working with enabled modifier
* performance with modifiers
  * x/per minute relative to pixel count
* double check modifier migration
* fix strip_index


## Wont do
* read led_structure from controller
* ping pong sawtooth, fade out
* cleanup: get rid of pub_sub rate limit (maybe not?)
* handshake/ack commands and retry
* position 16bit
* x for disable
* optionally avoid overlap in random transistion
* persistence per led structure
* fix docs for packet format
* modifier_incresae events
* kill uart when there is no connection
* more scaling for bigger structures
* batch UDP commands
* transitions for changes in modifier period (hard)
* Rotate effect, rotate over strips
