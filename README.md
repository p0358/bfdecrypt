# bfdecrypt
Utility to decrypt App Store apps on jailbroken iOS 12/13/14/15 (tested only on 15 with palera1n and clang from ProcursusTeam)

## Decrypt App Store apps on Odyssey

To get started, open bfdecrypt's preferences and turn on the switch for the app which you would like to decrypt. Then open the app.

You'll see this screen on your device:

<img src="https://i.imgur.com/z8HkeIB.png" width="400px"/>

Once it's complete, you'll be presented with this UI alert:

<img src="https://i.imgur.com/oTKNDCs.png" width="400px"/>

Pretty self-explanatory. The output path will also be logged in the device console log.

You can also search the filesystem for the IPA like so:

```
find /var/mobile/Containers/Data/Application/ -name decrypted-app.ipa -type f
```

The .ipa will be a clone of the original .ipa from the App Store, except that the main binary and all its accompanying frameworks and shared libraries will be decrypted. The CRYPTID flag will be 0 in each previously-encrypted file. You can take the .ipa, extract the app, modify it as needed, re-sign it with your own developer cert, and deploy it onto non-jailbroken devices as needed.


Here's an example using https://github.com/p0358/bfinject to decrypt the MyAnimeList app on an Odyssey-jailbroken iPhone:

```
Injecting /Library/TweakInject/bfdecrypt.dylib
[bfdecrypt] Spawning thread to do decryption in the background...
[bfdecrypt] All done, exiting constructor.
[bfdecrypt] Inside decryption thread
[dumpDecrypted] docPath: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents
[dumpDecrypted] init: appDirName: MyAnimeList.app
[bfdecrypt] Full path to app: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/MyAnimeList   ///   IPA File: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/decrypted-app-temp.ipa
[dumpDecrypted] ======== START FILE COPY - IGNORE ANY SANDBOX WARNINGS ========
[dumpDecrypted] IPAFile: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/decrypted-app-temp.ipa
[dumpDecrypted] appDir: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] appCopyDir: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa/Payload/MyAnimeList.app
[dumpDecrypted] zipDir: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa
[dumpDecrypted] ======== END OF FILE COPY ========
[dumpDecrypted] ======== START DECRYPTION PROCESS ========
[dumpDecrypted] There are 532 images mapped.
[dumpDecrypted] image 0
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/MyAnimeList to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 0: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/MyAnimeList
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] encryptedImagePathStr: MyAnimeList
[dumpDecrypted] make_directories making dir: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa/Payload/MyAnimeList.app
[dumpDecrypted] offset to cryptid (1) found in memory @ 0x104478fd0 (from 0x104478000). off_cryptid = 4048 (0xfd0)
[dumpDecrypted] Dumping: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/MyAnimeList
[dumpDecrypted]    Into: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa/Payload/MyAnimeList.app/MyAnimeList
[dumpDecrypted] Reading header
[dumpDecrypted] Detecting header type
[dumpDecrypted] Executable is a plain MACH-O image, fileoffs = 0
[dumpDecrypted] Opening /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa/Payload/MyAnimeList.app/MyAnimeList for writing.
[dumpDecrypted] Copying the not encrypted start of the file (20480 bytes)
[dumpDecrypted] Dumping the decrypted data into the file (4096 bytes)
[dumpDecrypted] Copying the not encrypted remainder of the file (5025152 bytes)
[dumpDecrypted] Setting the LC_ENCRYPTION_INFO->cryptid to 0 at offset 0xfd0 (0xfd0 into file)
[dumpDecrypted] image 1
[dumpDecrypted] Comparing /usr/lib/TweakInject.dylib to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 2
[dumpDecrypted] Comparing /usr/lib/libc++.1.dylib to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 3
[dumpDecrypted] Comparing /usr/lib/libsqlite3.dylib to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 4
[dumpDecrypted] Comparing /usr/lib/libz.1.dylib to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 5
[dumpDecrypted] Comparing /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 6
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/FBLPromises.framework/FBLPromises to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 6: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/FBLPromises.framework/FBLPromises
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] CryptID = 0!!
[dumpDecrypted] image 7
[dumpDecrypted] Comparing /System/Library/Frameworks/Foundation.framework/Foundation to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 8
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/GoogleUtilities.framework/GoogleUtilities to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 8: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/GoogleUtilities.framework/GoogleUtilities
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] CryptID = 0!!
[dumpDecrypted] image 9
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/Hydra.framework/Hydra to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 9: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/Hydra.framework/Hydra
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] CryptID = 0!!
[dumpDecrypted] image 10
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/Protobuf.framework/Protobuf to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 10: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/Protobuf.framework/Protobuf
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] CryptID = 0!!
[dumpDecrypted] image 11
[dumpDecrypted] Comparing /System/Library/Frameworks/QuartzCore.framework/QuartzCore to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 12
[dumpDecrypted] Comparing /System/Library/Frameworks/Security.framework/Security to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 13
[dumpDecrypted] Comparing /System/Library/Frameworks/StoreKit.framework/StoreKit to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 14
[dumpDecrypted] Comparing /System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 15
[dumpDecrypted] Comparing /System/Library/Frameworks/UIKit.framework/UIKit to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] image 16
[dumpDecrypted] Comparing /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/nanopb.framework/nanopb to /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app
[dumpDecrypted] Dumping image 16: /private/var/containers/Bundle/Application/3596183A-F503-4CFA-9C02-CDE3171BF312/MyAnimeList.app/Frameworks/nanopb.framework/nanopb
[dumpDecrypted] detected 64bit ARM binary in memory.
[dumpDecrypted] CryptID = 0!!
< a few less interesting lines cut off >
[dumpDecrypted] ======== DECRYPTION COMPLETE  ========
[dumpDecrypted] ======== STARTING ZIP ========
[dumpDecrypted] IPA file: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/decrypted-app-temp.ipa
[dumpDecrypted] ZIP dir: /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/ipa
[dumpDecrypted] ========  ZIP operation complete: success ========
[dumpDecrypted] ======== Wrote /var/mobile/Containers/Data/Application/006F9236-A31D-4214-BE8E-3DBEE90C8B4E/Documents/decrypted-app.ipa ========
[bfdecrypt] Over and out.
```

## Compatibility
This is been tested successfully with Odyssey(ra1n).

## Credits

- Carl Livitt @ Bishop Fox – the original tool, i.e. most of the stuff in this repo
- [@lechium](https://github.com/lechium) – updating this tool for tvOS 12
- @p0358 – converting to Theos project, small fixes to support iOS 13, convenient alert with actions after decryption is done
