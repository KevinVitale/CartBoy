# Features

- [x] Native macOS 🎉
- [x] Quick transfer speeds 🚀
- [x] Copy ROMs from your physical cartridges 📦
- [x] Write ROMs to your own flash carts ⚡️
- [x] Backup / Restore / Erase game save files 👾

# CartBoy
<img width=600 src="./Misc/Readme/CartBoy-Promo.png" />

# CartKit
`CartKit` is a companion framework, used by _CartBoy_, that
defines general device support and functionality.

#### `CartridgeController`
The `CartridgeController` protocol is adopted by a device (such
as `insidgeGadgetsController`) that is capable of the following:

 - Reading the cartridge header; and,
 - copying the cartridge ROM; and,
 - backing up save data (if supported); and,
 - restoring save data (if supported); and,
 - deleting save data (if supported); and,
 - flashing new ROMs to compatible cartridges; and,
 - erasing existing ROMs from compatrible cartridges.

A `CartridgeController` performs its functions from a `perform` 
block (which runs on its own `DispatchQueue`); devices cannot
be instantiated directly, thus the `perform` block is passed the
result of a controller that can be used.

##### Read cartridge header
Simply `flatMap` a `controller` into the `header` function, and
check the `Result`.

```swift
// Note: `perform` block is performed on a separate queue.
insideGadgetsController.perform { controller in
	switch controller.flatMap({ $0.header(for: GameboyClassic.self) })	
	{
		case .success(let header): (/* do something w/header */)
		case .failure(let error):  (/* handle error */)
	}
}
```

##### Copy cartridge ROM
Similarly, to copy a cartridge's ROM to your Mac, `flatMap`
the `controller` into the `cartridge` function—which also
includes a callback updating the __progress__—and check the
`Result`.

```swift
// Note: `perform` block is performed on a separate queue.
insideGadgetsController.perform { controller in
	switch controller.flatMap({ $0.cartridge(for: GameboyClassic.self, progress: { print($0) }) })
	{
		case .success(let cartridge): (/* do something w/cartridge */)
		case .failure(let error):  (/* handle error */)
	}
}
```
# Acknowledgements
Special thanks to:
- armadsen
- insideGadgets

# License
```
Copyright (c) 2019 Kevin J. Vitale

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal 
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE 
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
