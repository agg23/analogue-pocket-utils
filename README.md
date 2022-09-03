# Collection of Analogue Pocket Utilities

A collection of useful IP and information on how to develop [openFPGA](https://www.analogue.co/developer/docs/overview) cores for the [Analogue Pocket](https://www.analogue.co/pocket).

For tips, tricks, and various learnings from a software dev's perspective, [check out the wiki](../../wiki).

## IP

When possible, IPs will be provided with test benches.

| HDL File         | Usage                                                                                                               |
|------------------|---------------------------------------------------------------------------------------------------------------------|
| data_loader_8.v  | Converts APF writes into four bytes                                                                                 |
| data_loader_16.v | Converts APF writes into two bytes                                                                                  |
| hex_loader.v     | Converts APF writes representing a hex file into bytes. Can be converted for use outside of APF. Has an involved TB |
