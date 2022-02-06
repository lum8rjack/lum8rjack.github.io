---
title: "Function Hooking Part 3 - Frida"
date: 2022-02-06
categories: [ "function-hooking" ]
tags: ["windows", "frida", "password manager"]
draft: false
---

This post will wrap up the function hooking series. You can view the previous posts here:

* [Function Hooking Part 1 - Test Program]({{< ref "function-hooking-part-1.md" >}})
* [Function Hooking Part 2 - Password Safe]({{< ref "function-hooking-part-2.md" >}})

In this post I will show another method you can use to hook functions. Instead of writing an injector and DLL in C++, I will be using a tool called Frida that allows you to do the same with Python and JavaScript.

## What Is Frida?
[Frida](https://frida.re) is a "Dynamic instrumentation toolkit for developers, reverse-engineers, and security researchers." Frida lets you inject snippets of JavaScript into native apps on Windows, macOS, GNU/Linux, iOS, Android, and QNX.

## Revisiting Password Safe
If you remember from the previous post, I identified the Password Safe function that checks if the provided password is correct in order to unlock the safe. A function signature was created and added to the C++ code to compile a DLL that could intercept the password when it was submitted.

Since then, I created a Ghidra script called [CreateFunctionSignature.py](https://github.com/lum8rjack/GhidraHelp) that takes the function name and creates the signature for you. The output provides multiple formats of the bytes to be used with different tools or programing languages. The example below uses the script to identify the same signature for the CheckPassKey function in pwsafe.

```
CreateFunctionSignature.py> Running...
The currently loaded program is: 'pwsafe.exe'
Creating signature for the function: CheckPassKey
Function: CheckPassKey @ 0x00746cb0
Signature length: 28
Signature: 558bec83ec10b8cccccccc8945f08945f48945f88945fc8b450c8b48
Signature: [0x55, 0x8b, 0xec, 0x83, 0xec, 0x10, 0xb8, 0xcc, 0xcc, 0xcc, 0xcc, 0x89, 0x45, 0xf0, 0x89, 0x45, 0xf4, 0x89, 0x45, 0xf8, 0x89, 0x45, 0xfc, 0x8b, 0x45, 0x0c, 0x8b, 0x48]
Signature: 55 8b ec 83 ec 10 b8 cc cc cc cc 89 45 f0 89 45 f4 89 45 f8 89 45 fc 8b 45 0c 8b 48 
Signature: \x55\x8b\xec\x83\xec\x10\xb8\xcc\xcc\xcc\xcc\x89\x45\xf0\x89\x45\xf4\x89\x45\xf8\x89\x45\xfc\x8b\x45\x0c\x8b\x48
Mask: xxxxxxxxxxxxxxxxxxxxxxxxxxxx
CreateFunctionSignature.py> Finished!
```

## Frida JS

The JavaScript code below is similar to the DLL we previously created. The code will be injected into the application and will intercept the CheckPassKey function based on the function signature. The code will store the passkey the user submitted, along with the path to the database, and then output the results to the console if the passkey was correct.

```javascript {linenos=table}
// Find the module for the program itself, always at index 0:
const m = Process.enumerateModules()[0];

// The pattern that you are interested in:
const pattern = '55 8b ec 83 ec 10 b8 cc cc cc cc 89 45 f0 89 45 f4 89 45 f8 89 45 fc 8b 45 0c 8b 48';

console.log("[+] Scanning started");
console.log("[+] Base address: ", m.base);
console.log("[+] Module size:  ", m.size);

function doit(pointer) {
	Interceptor.attach(pointer,
	{
		// Arguments we know from the source code of the application
		//args: (const StringX &filename, const StringX &passkey, VERSION &version)
		onEnter(args) {
			this.arg0 = Memory.readUtf16String(args[0].readPointer()); // stores the path to the database
			this.arg1 = Memory.readUtf16String(args[1].readPointer()); // stores the password
		},

		//returns an int: 0 correct and 5 is incorrect passkey
		onLeave(retval) {
			if(retval == 0) {
				console.log("[+] Database:  " + this.arg0);
				console.log("[+] Password:  " + this.arg1);
			}
		}
	});
}
  
Memory.scan(m.base, m.size, pattern, {
  onMatch(address, size) {
    console.log('[+] Memory.scan() found match at', address, 'with size', size);
	doit(address);
    // Optionally stop scanning early:
    return 'stop';
  },
  onComplete() {
    console.log('[+] Memory.scan() complete');
  }
});
```

I won't explain every line of the JavaScript code, but below details a few of the main focus areas:
- **Line 31:** Scan the application to find where the function is we want to hook
- **Line 32-34:** If there is a match, the address is sent to the 'doit' function
- **Line 12:** Attach to the function
- **Line 16-19:** Intercept the arguments to the function and save them as variables
- **Line 22-27:** If the passkey was correct, the passkey and database location are output to the console

## Execution

The Python code is similar to the injector I created in the first post and is used to load and invoke Frida. Frida will take the JavaScript code and inject it into the application. The Python [script](https://github.com/lum8rjack/FunctionHooking/blob/main/Part3/fridaStart.py) is pretty simple and can be used for other projects as well. It takes two arguments, the JavaScript code to inject and the PID or name of the application we will be injecting into.

```
> python fridaStart.py --script CheckPassKey.js --pid 6056
Attached to PID: 6056
[+] Scanning started
[+] Base address:  0xb10000
[+] Module size:   8712192
[+] Memory.scan() found match at 0xe56cb0 with size 28
[+] Memory.scan() complete
[+] Database:  C:\Users\IEUser\Documents\My Safes\pwsafe.psafe3
[+] Password:  password123
```

You can see from the output above, that the JavaScript first finds the base address of the application and scans for the function. Once the function address is identified, it intercepts the argements and outputs them to the screen. Instead of outputing the results to the console, I could update the JavaScript code in order to send the results back to Python. This would allow me to easily save the details to a file or perform additional analysis.

## Wrap-Up
While this method of using Frida may not be as stealthy to implement in a penetration test or red team engagement, it does make it easier to create quick POCs. I find it much quicker to write the logic in Python and use the Frida Javascript API instead of C++ when first analyzing an application. In the References section below, I included a few addtional links to blogs where others have used Frida for hacking games or fuzzing.  

Example code - https://github.com/lum8rjack/FunctionHooking

## References

* Frida - https://frida.re/
* Learn Frida - https://learnfrida.info/
* Beginning Frida Book - https://www.amazon.com/Beginning-Frida-Learning-Android-JavaScript-ebook/dp/B094ZNR1MV/ref=sr_1_1?crid=21JQOO7K2D218&keywords=frida+reverse+engineering+book&qid=1643771486&sprefix=frida+reverse+engineeringbook%2Caps%2C74&sr=8-1
* In-Process Fuzzing With Frida - https://bananamafia.dev/post/frida-fuzz/
* Hacking a game to learn FRIDA basics (Pwn Adventure 3) - https://x-c3ll.github.io/posts/Frida-Pwn-Adventure-3/

