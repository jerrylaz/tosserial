# tosserial
Lazarus serial port component for Windows and Linux

Yet another comport component for Windows and Linux.

What is so special about this comport component? Aside from the usual ONRECEIVE event where all RX goes, you can now route the received data into your code where you need it.

[Blocking] example:

var s: String;

begin

  comport.WriteBufAsHexStr('55 0F 2B 00 1C'); //transmit hex $55,$0F,$2B,$00,$1C
  
  //expect to do something with the reply
  
  if comport.SyncRead(100) then begin //SyncRead(timeout: Integer=500), timeout to wait for a reply is in millisecond, default to 500 ms if not specify.
  
    s := comport.ReadBufAsHexStr; //reply in Hex is received as string in the format '55 01 23 FF'
    
    WriteLn(s);
    
  end else begin
  
    WriteLn('Receive timeout');
    
  end;
  
end;


[Non-blocking] example:

//for lenghty operation  
    ...
		comport.WriteString('Get EEPROM dump');
		While not comport.AsyncRead(ReceivedBytes, HadTimeout) do begin
		  Write('Bytes rx: ' + IntToStr(ReceivedBytes)); //display bytes received
      //.. do anything here
		end;
		if HadTimeout then begin
		  WriteLn('Operation has timeout');
		end else begin
		  EEpromDump := comport.ReadString;
      WriteLn(EEpromDump);
		end;

For more examples and usage, read the file Version.txt .

For bugs, suggestion or feedback, send email to jerry_my@hotmail.com
