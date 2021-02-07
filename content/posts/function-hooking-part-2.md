---
title: "Function Hooking Part 2 - Password Safe"
date: 2021-02-06
categories: [ "function-hooking" ]
tags: ["windows", "dll injection", "ghidra", "password manager"]
draft: false
---

In this post I will expand on the information from my first post, [Function Hooking Part 1 - Test Program]({{< ref "function-hooking-part-1.md" >}}). Previously, I discussed hooking a function from a custom application, in this post I will be hooking a function in the open-source password manager [Password Safe](https://pwsafe.org/). 

As you can image, password managers are valuable targets during red team engaments since they contain additional credentials for other services or computers. If the main password to open the database is known or obtained, then all of the other credentials in the database are compromised.

## What Is Password Safe?
Password Safe is a free and open-source password manager. A password manager is "a computer program that allows users to store, generate, and manage their passwords for local applications and online services. A password manager assists in generating and retrieving complex passwords, storing such passwords in an encrypted database or calculating them on demand." (https://en.wikipedia.org/wiki/Password_manager).

Like many other password managers, Password Safe has functionality that includes:
* Password management - Stores passwords securely and can be sectioned into groups
* Import and export - Ability to export passwords to TXT or XML and also import passwords from TXT or CSV files
* File encryption - Ability to encrypt files
* Password generator - Built-in password generator

![pwsafe_example](/img/FunctionHooking2/pwsafe_example.png)

Other password managers include:
* [KeePass](https://keepass.info/)
* [Lastpass](https://www.lastpass.com/)
* [1Password](https://1password.com/)

## Using Password Safe
Before I begin finding signatures and writing code, it is important to understand how the application works. I have installed Password Safe version 3.54  with the pwsafe.exe file details below.

![pwsafe_version](/img/FunctionHooking2/pwsafe_version.png)

When the program is first executed, it requires the user to either select a database or create a new one.

![pwsafe_startup](/img/FunctionHooking2/pwsafe_startup.png)

When I click on New, it asks for the name of the database and location.

![pwsafe_new](/img/FunctionHooking2/pwsafe_new.png)

After clicking Save, it then asks me to set the safe combination passkey.

![pwsafe_new_passkey](/img/FunctionHooking2/pwsafe_new_passkey.png)

Once completed, it opens a blank database.

![pwsafe_open_blank](/img/FunctionHooking2/pwsafe_open_blank.png)

I can then add new entries by clicking on Edit -> Add Entry...

![pwsafe_add_entry](/img/FunctionHooking2/pwsafe_add_entry.png)

I can provide the username, password, URL, and any additional notes that might be useful to save. Having to only remember one master password to access all other account information is a major benefit to password managers.

![pwsafe_example](/img/FunctionHooking2/pwsafe_example.png)

You can see from the image above, I have added a few extra entries and grouped them by different categories.

Now that the database is setup, the next step it figuring out how to gain access to the master passkey.


## Function Signature
Just like in [Part 1]({{< ref "function-hooking-part-1.md" >}}), I first need to find the function to hook. From testing Password Safe, I know I want to hook the function that checks if the provided password to open the database is correct or not. Since Password Safe is open-sourced, I start by looking through the source code.

![pwsafe](/img/FunctionHooking2/github_pwsfile.png)

It looks like the "CheckPasskey" function arguments include the filename of the database, the passkey, and also the version of the database. Hooking this function will allow me to intercept the correct passkey and save it to a text file.

Next, I load the pwsafe.exe binary into Ghidra and analyze the file. The file does not include debugging symbols like our test program from before, so it makes it harder to search for the function name. I first search for strings containing "CheckPasskey".

![re_strings](/img/FunctionHooking2/re_search_strings.png)

I clicked on the first entry and can see the decompiled code below the search box. I then right clicked on the section in the listing view and clicked References -> Show References to Address.

![re_references](/img/FunctionHooking2/re_references.png)

It shows one reference that is included in the "FUN_0075a5f0" function. I then right click on the function name in the decompiler view to search for functions that reference the "FUN_0075a5f0" function.

![re_references2](/img/FunctionHooking2/re_references2.png)

Clicking on the first reference shows me a function that looks almost identical to the "CheckPasskey" function I was looking for. The function takes three arguments and performs similar checks by passing them to other functions that seem to be related.

![pwsafe](/img/FunctionHooking2/re_ghidra.png)

Similar to the test program in part 1, I identify the first few bytes of the function in order to create the function signature.

## Writing The DLL
Now I have all of the information I need in order to create the DLL that will be injected into the program. The "DllMain" function identifies the "pwsafe.exe" program in memory, searches for the "CheckPasskey" signature we identified earlier, and then jumps to the hook function "HookCheckPasskey".

![dll_main](/img/FunctionHooking2/pwsafeDLL_main.png)

This fuction takes in the same parameters as the "CheckPasskey" function from Password Safe. The parameters are initially passed to the orignial function so I can receive the return value. If the return value is "0", I know that the passkey entered was correct and I can save the passkey to the output file. I had to create the "convertString" function to properly retrieve the data from memory.

![dll_hook](/img/FunctionHooking2/pwsafeDLL_HookCheckPassKey.png)

During my testing, I attached [x64dbg](https://x64dbg.com/) debugger to find the passkey in memory. Since the DLL is writing the memory addresses of the original function to the output file, it is easy to find the passkey in the memory dump.

![x32dbg](/img/FunctionHooking2/x32dbg_passkey.png)

The passkey "password123" starts at memory address 0x01499080 where you can see each character is followed by a null byte. The "convertString" function takes three parameters: text that will be saved to the output file, the memory address where the passkey is located, and the length of the passkey.

The function calculates the number of bytes to read based off the length of the passkey and the extra null bytes. Then the function loops through the bytes and outputs the characters to the output file that are not null bytes. 

![convert_string](/img/FunctionHooking2/pwsafeDLL_convertString.png)

Every time Password Safe tries calling the "CheckPasskey" function, I will now be able to intercept and save the passkey to a file.

## Testing
Now it is time to test out the DLL. After starting the application, I inject the DLL and can see the address of the original "CheckPasskey" function.

![injected](/img/FunctionHooking2/injected.png)

By entering in the correct passkey, the output file now contains the passkey and database information.

![injected_correct](/img/FunctionHooking2/injected_correct.png)

As you can see in the image below, the injected DLL will continue to save the output each time the user unlocks the database. The "detached" message will be written once the program has exited.

![injected_multiple](/img/FunctionHooking2/injected_multiple.png)

I also tested the application by entering in a wrong passkey. It shows the wrong passkey was entered but does not write anything to the output file.

![injected_wrong_passkey](/img/FunctionHooking2/injected_wrong_passkey.png)

## Conclusion
These same techniques can be applied to other password managers or any other application. It can be used to to intercept data or add additional functionality to an application.

Example code - https://github.com/lum8rjack/FunctionHooking

## References

* Password Safe - https://pwsafe.org/
* Password Safe source code - https://github.com/pwsafe/pwsafe

