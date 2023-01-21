# UI 
* Apply new style to navigation
* Rework presets 


# nice to have
* properly set max value for modifiers
* close all modals on Enter
* display loaded preset somewhere more prominent
* Commands should stay selected when path == /commands/1

# Tr33
* ping pong period, don't jump on change
* sawtooth reverse not working

# Random/noise effect
* Fade with random speed black -> color -> white

# Interaction with Firmware
* Send all commands at once

# Bugs/features
* timeout UDP when no metrics are received
* gravity not working
* add random toggle to each slider (or some)
* white color palette
* mapped ping_pong
* regular preset backups
* order branch and trunk indices/PINs
* use some effects from WLED
* movement_type (or render option) circle (for trommel and others)
* Idea for testing: create some sequence that uses all features
* mapped position to 16bit
* movement_type: steps, steps_transition
* Sync time between ESPs
* Sync random seed betwenn ESPs
* effects relative to strip height/prixel count
  * gravity height relative to strip length
* fix add ball for gravity
* random walk for tr33
* diffusion (lava lamp) effect
* move slope, or render in general: color shift effect (or similar) instead of solid color 
  * slope -> change/shift color effect 
* bug in mapped slope: use perpendicular distance instead of y distance
* generally more effects like kaleidoscope
* mapped 2D bouncing ball
* softer sparkle
* joystick


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
