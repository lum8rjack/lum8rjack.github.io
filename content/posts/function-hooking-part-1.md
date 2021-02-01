---
title: "Function Hooking Part 1 - Test Program"
date: 2021-01-31
categories: [ "function-hooking" ]
tags: ["windows", "dll injection", "ghidra"]
draft: false
---

I have recently been spending time learning more about reverse engineering and patching applications including fixing older programs that I do not have the source code for. I've started looking into function hooking and identifying how it works and different scenarios I could use it. There are a ton of articles online but most of them do not provide simple examples for starters or are focused on Windows API. While Windows API hooking is useful, I am more interested in hooking higher level functions.

I'm going to walk through an example of hooking a small custom application and what tools and libraries I have found useful. Hopefully this example will help others that are wanting to get started with function hooking.

## What Is Function Hooking?
Function hooking is a technique that allows the user to intercept and redirect the execution of a function in a running application. This can be combined with DLL injection to patch a program that cannot be recompiled (i.e. the user doesn't have the source code) or to add new functionality (i.e. adding a new feature to a game). Some reasons to use function hooking on red team engagements include:

* Intercepting and/or manipulating data before it is processed or sent somewhere 
    * https://www.ired.team/offensive-security/code-injection-process-injection/api-monitoring-and-hooking-for-offensive-tooling
* Disabling functionality

There are many other articles out there that can explain function hooking better than I can. One article you can checkout is http://kylehalladay.com/blog/2020/11/13/Hooking-By-Example.html.

## Overview
Now that you know what function hooking is, how can this be used? Let's start by creating an application that can hook a specific function. Having the source code will make it easier to reverse engineer in order to find and write a signature for the function compared to starting out with a larger, closed source application.

While Windows API function hooking may be useful in different scenarios, there may also be times you would want to hook a custom function. If you have ever used API Monitor (http://www.rohitab.com/apimonitor) to view the API calls an application uses, you may find it overwhelming with the number of requests being made. This may also make it hard to focus in on the specific area of the application you are wanting to monitor or manipulate.

Our example will create a simple console application that adds two numbers together and prints the result to the console. Using this program you will create a DLL, that when it's injected into the program, will alter the functionality of the function that adds the numbers.

When initially searching for references around function hooking it was hard to find anything that wasn't specific to Windows API hooking. I was able to find https://github.com/Zer0Mem0ry/Detour which provides some code examples on function hooking. The repository does not have any documentation so I had to search through the code to figure out how to get the pieces to work. Most of the code and ideas in this post come from that repository.

## Writing The Program
I started by creating my own application. As mentioned previously, I based most of my code and ideas from https://github.com/Zer0Mem0ry/Detour. I created a similar test application that outputs the sum of two numbers.

![test](/img/FunctionHooking1/testSum.png)

This program has a continuous loop that calls the "sum" function to add two numbers together, prints the output, and then sleeps for 5 seconds. I wanted to hook the "sum" function and change the integers being passed to it.

## Function Signature
Now that the program is compiled, I needed to identify where at in the program the "sum" function was located so I analyzed the program by loading it into Ghidra.

![entry](/img/FunctionHooking1/findSignature.png)

Since the program was compiled without stripping any debug symbols, it is easy to see the decompiled "main" function looks almost identical to the C code. Clicking on the "sum" function in the decompiler window or in the symbol tree in on the left, will show the decompiled function.

![sum](/img/FunctionHooking1/findSignature2.png)

Just like the "main" function, this one also looks similar to our C code. Looking in the middle at the listing window, you can see the "sum" function starts at address 0x00401530. This address might not be the same when executed, so I needed to search for this function based off of the bytes that make up the function. Next to the address, you can see the function starts with 0x55. I took the first X bytes of the "sum" function and injected the DLL to scan for these in memory when the program is running. This allowed me to hook the function and make whatever changes I wanted. The number of bytes needed will depend of the application. The larger the application, the more bytes will likely be needed in order to narrow the search down to one unique location.

![xxd](/img/FunctionHooking1/findSignature3.png)

As seen in the image above, the 9 bytes I selected were only identified once in the program. The next step was to create the DLL that will scan for this function and perform the hooking.

## Writing The DLL
The DLL will utilize Microsoft Detours to intercept and re-write the in-memory code for the target function. A more detailed overview of what Detours is can be found here: https://www.microsoft.com/en-us/research/project/detours/. In addition to Detours, I utilized the signature scanner code from Zer0Mem0ry (https://github.com/Zer0Mem0ry/Detour/blob/master/dll/sigscan.h) in order to find the function in memory.

I created a new C++ DLL project in Visual Studio and imported Detours via the Nuget Package manager (Project -> Manage NuGet Packages... -> Browse -> Detours -> install). I also included the "sigscan.h" header to the project. Once all that was completed, the code below was added to the project and compiled to a DLL.

![dll](/img/FunctionHooking1/testHook.png)

Let's walk through a few main parts of the code:
* When the DLL is injected and attached to the process, it first prints out "Injected". This is just to let you know the injection worked.
* I initialized the "SigScanner", specified the program to search through in memory (test32.exe), and specified the signature of the "sum" function that was found previously (line 30).
* At line 32, the scanner searched for the address of the function and then prints it out to the user on line 33.
* The remainder of the function is using the Detours library. Detours takes the address and performs the hooking function (line 37) to redirect the execute of that function to the new function "HookSum".
* When the process is detached, Detours does some cleanup activity.

Jumping up to the "HookSum" function:
* The function will print additional information to the console.
* The function will then manipulate the integers that were intially passed to the function.
* At the end, the function turns execution back to the original "Sum" function. This step could be optional depending on what you're planning on using the hook for.

## Testing
Now that everything is compiled, let's test it out.

![hooking](/img/FunctionHooking1/hooking.png)

As you can see in the left console, the program initially runs like normal and prints out the sum of 5+5. After injecting the DLL, you can see that it was successfully injected and prints the address of the "sum" function. It then started printing out the modified sum of 5+5.

## Conclusion
In this example I am only demonstrating one simple way to hook a function. While this example may not be useful in real life, it should provide an understanding of how function hooking works.

In part 2, I will cover using these same concepts against a known application and how it could be used during a red team engagement.

The example code can be found here: https://github.com/lum8rjack/FunctionHooking

## Acknowledgements
Below are a few additional resources and tools.

* Concepts of function hooking - https://github.com/Zer0Mem0ry/Detour
* Signature scanner used in the example - https://github.com/Zer0Mem0ry/SignatureScanner
* Microsoft Detours library - https://github.com/microsoft/Detours
* Hooking example - http://kylehalladay.com/blog/2020/11/13/Hooking-By-Example.html
* Hooking tutorial - https://www.codeproject.com/Articles/29527/Reverse-Engineering-and-Function-Calling-by-Addres

