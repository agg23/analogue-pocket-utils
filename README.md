# Collection of Analogue Pocket Utilities

A collection of useful IP and information on how to develop [openFPGA](https://www.analogue.co/developer/docs/overview) cores for the [Analogue Pocket](https://www.analogue.co/pocket).

For tips, tricks, and various learnings from a software dev's perspective, [check out the wiki](../../wiki).

## IP

When possible, IPs will be provided with test benches.

| HDL File         | Usage                                                                                                               |
|------------------|---------------------------------------------------------------------------------------------------------------------|
| mem/psram.sv     | Generic PSRAM controller, configured with timing for the Pocket's PSRAM. Supports synchronous access in async mode  |
| data_loader.sv   | Converts APF writes into configurable single or two byte words. TB tests both 8 and 16 bit writes                   |
| data_unloader.sv | Connects APF reads into memory fetches, with configurable single or two byte words. TB tests both 8 and 16 bit reads|
| hex_loader.v     | Converts APF writes representing a hex file into bytes. Can be converted for use outside of APF. Has an involved TB |
| sound_i2s.sv     | Provides audio over the i2s bridge. Supports signed and unsigned audio                                              |

### Debug Key
This example demonstrates controlling the Debug Key's LED with the button also on the key.

```verilog
wire LED;
wire button;

assign LED = button;

debug_key key (
    .cart_tran_bank0_dir(cart_tran_bank0_dir),
    .cart_tran_bank0(cart_tran_bank0),
    .cart_tran_bank3_dir(cart_tran_bank3_dir),
    .cart_tran_bank3(cart_tran_bank3),
    .LED(LED),
    .button(button)
);
```

## Tools

### Image Processing

* https://github.com/agg23/Analogue-Pocket-Image-Process - Small Node project to create and extract APF image bins
* https://github.com/codewario/PocketLibraryImageConversion - PS script to generate Library thumbnails

### Updaters

* https://github.com/mattpannella/pocket_core_autoupdate_net - C# updater
* https://github.com/rivergillis/update-pocket - Python updater

## Cores

Only open source cores are provided here. You can see the complete list at https://joshcampbell191.github.io/openfpga-cores-inventory/analogue-pocket.html

| Core         | Author                                        | URL                                                   |
|--------------|-----------------------------------------------|-------------------------------------------------------|
| Arduboy      | [agg23](https://github.com/agg23)             | https://github.com/agg23/analogue-arduboy             |
| Asteroids    | [ericlewis](https://github.com/ericlewis)     | https://github.com/ericlewis/openfpga-asteroids       |
| Lunar Lander | [ericlewis](https://github.com/ericlewis)     | https://github.com/ericlewis/openfpga-lunarlander     |
| Neo Geo      | [Mazamars312](https://github.com/Mazamars312) | https://github.com/Mazamars312/Analogue_Pocket_Neogeo |
| PDP-1        | [spacemen3](https://github.com/spacemen3)     | https://github.com/spacemen3/PDP-1                    |
| Pong         | [agg23](https://github.com/agg23)             | https://github.com/agg23/analogue-pong                |
| Space Race   | [ericlewis](https://github.com/ericlewis)     | https://github.com/ericlewis/openfpga-spacerace       |
| Tecmo        | [nullobject](https://github.com/nullobject)   | https://github.com/nullobject/openfpga-tecmo          |       
