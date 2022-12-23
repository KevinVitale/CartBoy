CartBoy [is no longer under active development](https://discord.com/channels/513663955562921984/586059097925746719/1055884526527713280). I'd recommend using [FlashGBX](https://github.com/lesserkuma/FlashGBX).

Thanks for all the support.

<hr />
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

#### `SerialDevice<GBxCart>`
The `SerialDevice<GBxCart>` is the cart reader device from
`insidgeGadgetsController` that is capable of the following:

 - Reading the cartridge header; and,
 - copying the cartridge ROM; and,
 - backing up save data (if supported); and,
 - restoring save data (if supported); and,
 - deleting save data (if supported); and,
 - flashing new ROMs to compatible cartridges; and,
 - erasing existing ROMs from compatrible cartridges.

A `SerialDevice<GBxCart>` cannot be instantiated directly; instead
use `open` on `GBxCart` and you'll receive an isntance.

##### Read cartridge header
Simply `open` a `SerialDeviceSession`, then read the `header`
(checking the `Result`):

```swift
GBxCart.open { serialDevice in
  switch serialDevice.header(forPlatform: GameboyClassic.self) {
  case .success(let header) :print(header)
  case .failure(let error)  :print(error)
  } 
}

```

##### Copy a cartridge's ROM
Some functions let you get updates on the progress of an operation
(such as when copying a cartridge to your Mac). In these cases **you
must call the operation from queue other than the main one**.

If you omit providing a progress callback, the operation blocks the
main thread; this maybe useful for a number of scenarios (such as unit
tests).

```swift
GBxCart.open { serialDevice in
  try {
    let cartridge = serialDevice
       .readClassicCartridge (progress: { print($0.fractionCompleted) })
       .write                (toDirectoryPath: "/Users/kevin/Desktop")
       .check                (MD5: "b259feb41811c7e4e1dc20167985c84") /* Super Mario Land? */
       .get()
     print(cartridge)
  } catch {
     print("\(error)")
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
