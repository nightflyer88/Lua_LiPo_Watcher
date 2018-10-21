# Rx Battery Monitor

Displays the receiver voltage in percent and displays it graphically.

In the settings just select the battery type (LiPo, Li-ion, Nixx) and cell number, and the app does the rest. In the large telemetry window, the effective battery voltage can also be displayed (single cell or total voltage). It is also possible to set an alarm when the level falls below a defined value.
The battery level is calculated using the battery-specific discharge curve, resulting in a relatively accurate value.

![screen000](https://raw.githubusercontent.com/nightflyer88/Lua_RxBattMon/master/img/Screen000.bmp)
![screen001](https://raw.githubusercontent.com/nightflyer88/Lua_RxBattMon/master/img/Screen001.bmp)
![screen002](https://raw.githubusercontent.com/nightflyer88/Lua_RxBattMon/master/img/Screen002.bmp)

```
Version history:
V1.6    21.10.18    cleanup, add LiFePo Battery type, optimize LiPo percent list
V1.5    07.03.18    add Li-ion cells
V1.4    26.12.17    Rename to RxBattMon, small changes
V1.3    02.11.17    Rx sensors are supported, Nixx cells are supported
V1.2    01.11.17    forked from RCT LiPo Watcher
```
