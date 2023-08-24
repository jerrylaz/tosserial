{******************************************************************************}
{  version: 0.5.7                                                              }
{  date: 20-6-2018                                                             }
{  Type: Serial port component (OpenScada Library - TOSSerial)                 }
{  Author: jerry_my@hotmail.com                                                }
{  Platform: Linux, Windows                                                    }
{******************************************************************************}

unit OSSerial;

{$mode objfpc}{$H+}

interface

uses
  {$ifndef windows}
  BaseUnix, Termio, Serial, Linux,
  {$else}
  Windows, Registry,
  {$endif}
  Classes, SysUtils, LResources, Forms, StrUtils;

const
  ver = '0.5.7'; //13-6-2022 Windows



Type
  TCrcFunction = function (data: array of byte; Len: Integer): TBytes;
  //TCrcFunctionEx = function (data: array of byte; StartIdx, Len: Integer): TBytes;

operator + (a: TBytes; b: TBytes): TBytes; overload;
function BytesToAsciiStr(dataBytes: array of byte; ALength: Integer; Spacing: Boolean = False): String;
function BytesToHexStr(dataBytes: array of byte; ALength: Integer;
                                 ByteSpacing: Boolean): String;
function HexStrToBytes(hex: String): TBytes;
function StrToBytes(s: String): TBytes;
function InsertBetween(src, substr: String; Spacing: Integer; AtBegin, AtEnd: Boolean): String;
function IEEE754ByteToFloat(b: array of byte): Single;
{ StartPos is 1 for first byte }
function SubBytes(srcBytes: array of byte; StartPos, Len: Integer): TBytes;
//EnumerateComport taken from https://forum.lazarus.freepascal.org/index.php?topic=16616.0
//by padiazg (windows).
function EnumerateComport(ShowFriendlyName: Boolean): String;

//==================== user editable functions ========================
function CRC_LINBusClassic(data: array of byte; Len: Integer): TBytes;
function CRC_LINBusEnhance(data: array of byte; Len: Integer): TBytes;
function CRC16_Modbus(data: array of byte; Len: Integer): TBytes;
function CRC16Swap_Modbus(data: array of byte; Len: Integer): TBytes;
function CRCTesoo(data: array of byte; Len: Integer): TBytes;
function MakeModbusFrame(data: String; CRC_Proc: TCrcFunction): TBytes;
//=====================================================================

type
  TPort = array of String;
  TCommType = (ctSerial);
  TLineBreak = (CR, LF, CRLF, LFCR);
  TBaudrate = array of dword;
  TStopBits = (ONESTOPBIT, ONE5STOPBITS, TWOSTOPBITS);
{$IFDEF WINDOWS}
  TParity = (NOPARITY, ODDPARITY, EVENPARITY, MARKPARITY);
{$ENDIF}
  TEVFlags = (evRXCHAR, evRXFLAG, evTXEMPTY, evCTS, evDSR,
             evRLSD, evBREAK, evERR, evRING, evPERR,
             evRX80FULL, evEVENT1, evEVENT2);
  TEVMask = set of TEVFlags;

  TEventType = (etRxChar, etRxFlag, etTxEmpty, etCTS, etDSR, etRLSD, etBreak,
                etErr, etRing, etPErr, etRx80Full, etEvent1, etEvent2);
  TReceiveMode = (rmByte, rmBuffer, rmProtocol);
  TDataDirection = (ddIn, ddOut);

  TCommEvent = procedure (EventType: TEventType) of object;

{$IFDEF WINDOWS}
  TCommStateChange = procedure (var aDCB: TDCB; var Allow: Boolean) of object;
{$ENDIF}
  //TReceiveEvent = procedure (RxBufferEmpty: Boolean) of object;

  TDebugEvent = procedure (b: TBytes; Len: Integer; Direction: TDataDirection) of object;
  TProtocolData = packed record
    ChecksumSize: byte;
    Checksum: word;
    DataArray: array of TBytes;
  end;

{$ifndef windows}
  TDCB = record
    Baudrate: dword;
    Bytesize: byte;
    Stopbits: byte;
    Parity: byte;
  end;
{$endif}

  TCustomOSSerial = class; //forward class declaration

  { TPortProperty }

  //TPortProperty = class (TStringProperty)
  //public
  //  function GetAttributes: TPropertyAttributes; override;
  //  procedure GetValues(Proc: TGetStrProc); override;
  //  procedure Edit; override;
  //end;

  { TFlowControl }




  { TSerialTimeouts }

//      Totaltimeout = (Multiplier * No. of Bytes) + Constant

  TSerialTimeouts = class (TPersistent)
  private
    FReadIntervalTimeout: dword;
    FReadTotalTimeoutMultiplier: dword;
    FReadTotalTimeoutConstant: dword;
    FWriteTotalTimeoutMultiplier: dword;
    FWriteTotalTimeoutConstant: dword;
    procedure SetReadInterval(AValue: dword);
    procedure SetReadTotalMultiplier(AValue: dword);
    procedure SetReadTotalConstant(AValue: dword);
    procedure SetWriteTotalMultiplier(AValue: dword);
    procedure SetWriteTotalConstant(AValue: dword);
  public
    constructor Create;
    destructor Destroy; override;
  published
    property ReadByteInterval: dword read FReadIntervalTimeout write SetReadInterval;
    property ReadByteMultiplier: dword read FReadTotalTimeoutMultiplier write SetReadTotalMultiplier;
    property ReadConstant: dword read FReadTotalTimeoutConstant write SetReadTotalConstant;
    property WriteByteMultiplier: dword read FWriteTotalTimeoutMultiplier write SetWriteTotalMultiplier;
    property WriteConstant: dword read FWriteTotalTimeoutConstant write SetWriteTotalConstant;
  end;

  TOSSerialRxThread = class;

  { TOSSerialTxThread }

  TOSSerialTxThread = class (TThread)
  private
    FOSSerial: TCustomOSSerial;
    FTXBuffer: TBytes;
    FWroteCount: Integer;
    FBeginWrite: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(OSSerial: TCustomOSSerial);
    destructor Destroy; override;
    procedure Write(data: TBytes; len: Integer);
  end;

  { TSyncReadTimer }

  TSyncReadTimer = class (TThread)
  private
    FEnded: Boolean;
    FOSSerial: TCustomOSSerial;
    {$ifdef windows}
    FQPFreq: int64; //query performance frequency
    FInterval: int64;
    FTick: int64;
    FuSec: int64;
    {$else}
    FInterval: cardinal;
    FTick: cardinal;
    {$endif}
    {$ifdef windows}
    {Interval in microseconds}
    procedure SetInterval(AValue: int64);
    {$else}
    {Interval in milliseconds}
    procedure SetInterval(AValue: cardinal);
    {$endif}
  protected
    procedure Execute; override;
  public
    Constructor Create(OSSerial: TCustomOSSerial);
    destructor Destroy; override;
    procedure Stop;
    procedure Restart;
    procedure SendSignal;
    property Ended: Boolean read FEnded;
    {$ifdef windows}
    property Interval: int64 read FInterval write SetInterval;
    {$else}
    property Interval: cardinal read FInterval write SetInterval;
    {$endif}
  end;

  { TOSSerialThread }

  { TOSSerialRxThread }

  TOSSerialRxThread = class (TThread) //thread for handling serial comm read
  private
    FCommEvent: TCommEvent;
    FCompleteEvent: TNotifyEvent;
    FOSSerial: TCustomOSSerial;
    FSyncReadTimer: TSyncReadTimer;
    {$ifndef windows}

    {$else}
    FEvEndProcess: TOVERLAPPED;
    {$endif}
  protected
    procedure Execute; override;
    {$ifndef windows}
    procedure ProcessEvRxChar;
    procedure ProcessEvRxCharLocal;
    {$else}
    procedure ProcessEvRxChar(Ovlap: POVERLAPPED);
    {$endif}
    property OnCommEvent: TCommEvent read FCommEvent write FCommEvent;
  public
    constructor Create(OSSerial: TCustomOSSerial);
    destructor Destroy; override;
  end;


  TOSModbusRTUObject = class;

  { TCustomOSSerial }

  TCustomOSSerial = class (TComponent)
  private
    FCS: TRTLCriticalSection;
    FNodeList: TList;
    FCommThread: TOSSerialRxThread;
    FCRCFunc: TCrcFunction;
    FDCB: TDCB;
    FEnabled: Boolean;
    FEventMask: dword;
    FEvMask: TEvMask;
    FHndComm: THandle;
    FOwner: TObject;
    //FPortName: String;
    FPort: String;
    FProtocol: String;
    FProtocolBuffer: TBytes;
    FProtocolCount: Integer;
    FRxCounter: cardinal;
    FTxCounter: cardinal;
    FVersion: String;
    FWriteThread: TOSSerialTxThread;
    FRxBufSize: dword;
    FTxBufSize: dword;
    FRxMode: TReceiveMode;
    {$IFNDEF WINDOWS}
    FSyncRead: PRTLEvent;
    {$else}
    FSyncRead: TOVERLAPPED;
    {$endif}
    FTimeouts: TSerialTimeouts;
    FRxBuffer: TBytes;
    FRxLength: word;
    FSkipOnReceive: Boolean;
{$IFDEF WINDOWS}
    FOnCommState: TCommStateChange;
{$ENDIF}
    FOnDebug: TDebugEvent;
    //FOnRxChar: TReceiveEvent;
    FOnReceive: TNotifyEvent;
    function ArgumentCount(s: String): Integer;
    function GetBaudRate: dword;
    function GetByteSize: byte;
    function GetNodeCount: Integer;
    function GetPortName: String;
    function GetSyncReadStatus: Boolean;
    function ProtocolCount(s: String): Integer;
    function DecodeProtocol(var b: TBytes; protocol: String; var ProtocolData: TProtocolData): boolean; //complete decode return true
    function DoGetCommMask: dword;
    function DoSetCommMask: Boolean;
{$IFDEF WINDOWS}
    function GetParity: TParity;
{$ELSE}
    function GetParity: TParityType;
{$ENDIF}
    function GetStopBits: TStopBits;
    procedure DoRxThreadCommEvent(EventType: TEventType);
    procedure SetBaudrate(AValue: dword);
    procedure SetDataBits(AValue: byte);
    procedure SetEnabled(AValue: Boolean);
    procedure SetEvMask(AValue: TEvMask);
{$IFDEF WINDOWS}
    procedure SetParity(AValue: TParity);
{$ELSE}
    procedure SetParity(AValue: TParityType);
{$ENDIF}
    procedure SetPortName(AValue: String);
    procedure SetProtocol(AValue: String);
    procedure SetRxBufSize(AValue: dword);
    procedure SetRxMode(AValue: TReceiveMode);
    procedure SetStopBits(AValue: TStopbits);
    procedure SetTxBufSize(AValue: dword);
  protected
    {$ifndef windows}
    procedure ReadBuffer;
    procedure ReadByte;
    {$else}
    procedure ReadBuffer(ovlap: TOVERLAPPED);
    procedure ReadByte(ovlap: TOVERLAPPED);
    {$endif}
    procedure AddToNodeList(Node: TOSModbusRTUObject);
    procedure DeleleFromNodeList(Node: TOSModbusRTUObject);
    { Internal used }
    function ReadQueue: Integer;
    { Internal used }
    function WriteQueue: Integer;
    property Enabled: Boolean read FEnabled write SetEnabled;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    function ReadBuf(out Buf; BytesToRead: word; ATimeout: word = 500): Integer; overload;
    function ReadBuf(out Buf): Integer; overload;
    { alias of ReadBuf() }
    function Read(out Buf): Integer;
    function ReadProtocolBuf(var Buf: TProtocolData): Integer;
    function ReadString: String;
    { alias to ReadString }
    function ReadStr: String;
    { alias to ReadString }
    function ReadData: String;
    { Read Hex and output as Hex string }
    function ReadBufAsHexStr: String;
    function PeekBuf(out Buf): Integer;

    {$ifndef windows}
    function WriteBuf(const Buf; len: Integer=0): Integer; overload;
    {$else}
    procedure WriteBuf(const Buf; len: Integer = 0);
    procedure Write(const Buf; len: Integer = 0);
    {$endif}
    { EscapeChar can be any char but preferably '\' so can write some string like 'Line1\r\nLine2' }
    procedure WriteString(S: String; EscapeChar: Char=#0);
    { alias to WriteString() }
    procedure WriteStr(S: String; EscapeChar: Char=#0);
    { alias to WriteString() with EscapeChar = #0 }
    procedure WriteData(S: String);
    { Write as Hex in string format without using TBytes.
      Format can be '00 OF A1 BD' or '000FA1BD' or '00 of a1 bd'
      This function will append the checksum automatically if CRC_Function is provided
    }
    function WriteStrAsHex(S: String): String;
    procedure ClearBuffer(RxBuffer, TxBuffer: Boolean);
    { Blocking function till timeout or data receive will unblock
      Return True if data received
      Return False if Timeout }
    function SyncRead(Timeout: cardinal=500): Boolean; //blocking
{$IFDEF WINDOWS}
    { Non-blocking function that will provide BytesRead info for lengthy operation such reading EEPROM dump
      Timeout = True if timeout
      returns: True if operation complete, False if still pending receiving more data }
    function AsyncRead(var BytesRead: word; out Timeout: Boolean): Boolean; //non-blocking
{$ELSE}
    { Non-blocking function that will provide BytesRead info for lengthy operation such reading EEPROM dump
      Timeout = True if timeout
      returns: True if operation complete, False if still pending receiving more data }
    function AsyncRead(var BytesRead: word; out Timeout: cardinal): Boolean; //non-blocking
{$ENDIF}

    function Open: Boolean;
    function IsOpened: Boolean;
    procedure Close;
    //function InputCount: Integer;
    function ChangeBaudRate(baud: dword): Boolean;
    function UpdateComState(aDCB: TDCB): Boolean;
{$IFDEF WINDOWS}
    function ChangeCOMSetting(Baudrate: dword; Databits: byte; Parity: TParity; Stopbits: TStopbits): Boolean;
{$ELSE}
    function ChangeCOMSetting(Baudrate: dword; Databits: byte; Parity: TParityType; Stopbits: TStopbits): Boolean;
{$ENDIF}
    procedure ResetCounters(Tx, Rx: Boolean);
    {
      CRC_Function works with WriteHexStr() function which will append the
      calculated checksum to the end of the Hex string.
    }
    property CRC_Function: TCrcFunction read FCRCFunc write FCRCFunc;
    property RxBufferCount: word read FRxLength;
    property RxBuffer: TBytes read FRxBuffer;
    property RxLength: word read FRxLength;
    property RxCounter: cardinal read FRxCounter;
    property TxCounter: cardinal read FTxCounter;
    property SyncReadInProgress: Boolean read GetSyncReadStatus;
    //property DebugRx: TStringList read FDebugRx;
  published
    property Baudrate: dword read GetBaudRate write SetBaudrate default 9600;
    property DataBits: byte read GetByteSize write SetDataBits default 8;
{$IFDEF WINDOWS}
    property Parity: TParity read GetParity write SetParity default NOPARITY;
{$ELSE}
    property Parity: TParityType read GetParity write SetParity default NoneParity;
{$ENDIF}
    property Port: String read GetPortName write SetPortName;
    property StopBits: TStopBits read GetStopBits write SetStopBits;
    property MonitorEvents: TEvMask read FEvMask write SetEvMask;
    property NodeCount: Integer read GetNodeCount;
    property Protocol: String read FProtocol write SetProtocol;
    property ReceiveMode: TReceiveMode read FRxMode write SetRxMode;
    property BufferSizeRx: dword read FRxBufSize write SetRxBufSize;
    property BufferSizeTx: dword read FTxBufSize write SetTxBufSize;
    property Timeouts: TSerialTimeouts read FTimeouts write FTimeouts;
//    property OnDebugRx: TNotifyEvent read FOnDebugRx write FOnDebugRx;
{$IFDEF WINDOWS}
    property OnCommStateChange: TCommStateChange read FOnCommState write FOnCommState;
{$ENDIF}
    property OnReceive: TNotifyEvent read FOnReceive write FOnReceive;
    //property OnReceive: TReceiveEvent read FOnRxChar write FOnRxChar;
//    property DebugTx: TEdit read FEditTx write SetFEditTx;
    property Version: String read FVersion;
    //property OnDebugData: TDebugEvent read FOnDebug write FOnDebug;
  end;

  { TOSSerial }
  TOSSerial = class (TCustomOSSerial)
  published
    property Baudrate;
    property BufferSizeRx;
    property BufferSizeTx;
    property DataBits;
    property MonitorEvents;
    property Parity;
    property Port;
    property Protocol;
    property ReceiveMode;
    property StopBits;
    property Timeouts;
    //property OnDebugData;
{$IFDEF WINDOWS}
    property OnCommStateChange;
{$ENDIF}
    property OnReceive;
    //property OnProtocol;
  end;

  { TOSModbusRTUObject }

    TOSModbusRTUObject = class (TComponent)
    private
      FFormat: String;
      FOSSerial: TOSSerial;
      FEnabled: Boolean;
      FCommand: String;
      FReply: String;
      function GetCRC: String;
      procedure SetCommand(AValue: String);
      procedure SetEnabled(AValue: Boolean);
      procedure SetFormat(AValue: String);
      procedure SetSerialCOM(AValue: TOSSerial);
    protected
    public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
    published
      property SerialCOM: TOSSerial read FOSSerial write SetSerialCOM;
      property Command: String read FCommand write SetCommand;
      property CommandCRC: String read GetCRC;
      property Enabled: Boolean read FEnabled write SetEnabled;
      property Reply: String read FReply;
      property FormatReply: String read FFormat write SetFormat;
    end;

  {$ifndef windows}

  {$else}
  const
    WM_DataReady = WM_User + 0;
  {$endif}

procedure Register;

implementation

procedure Register;
begin
  //RegisterComponents('Open Scada', [TOSSerial, TOSModbusRTUObject] );
  RegisterComponents('Open Scada', [TOSSerial] );
end;



operator + (a: TBytes; b: TBytes): TBytes;
begin
  SetLength(Result, Length(a) + Length(b));
  Move(a[0], Result[0], Length(a));
  Move(b[0], Result[Length(a)],Length(b));
end;

function BytesToAsciiStr(dataBytes: array of byte; ALength: Integer; Spacing: Boolean): String;
var i: Integer;
begin
  Result := '';
  //for i := 0 to ALength-1 do begin
  for i := Low(dataBytes) to High(dataBytes) do begin
    Assert(dataBytes[i] = 0, 'Data is 0!');
    if not Spacing then begin
      if (dataBytes[i] < $20) or
         ((dataBytes[i] >= $7F) and (dataBytes[i] < $A0)) then
        Result := Result + Format('%s ', [Chr($2E)])
      else
        Result := Result + Format('%s', [Chr(dataBytes[i])]);
    end else begin
      if (dataBytes[i] < $20) or
         ((dataBytes[i] >= $7F) and (dataBytes[i] < $A0)) then
        Result := Result + Format(' %s ', [Chr($2E)])
      else
        Result := Result + Format(' %s ', [Chr(dataBytes[i])]);
    end;
  end;
end;

function BytesToHexStr(dataBytes: array of byte; ALength: Integer;
  ByteSpacing: Boolean): String;
var i: Integer;
begin
  Result := '';
  for i := 0 to ALength-1 do begin
    Result := Result + Format('%.2x', [dataBytes[i]]);
    if ByteSpacing then begin
      if i < Length(dataBytes)-1 then
        Result := Result + ' ';
    end;
  end;
end;


function HexStrToBytes(hex: String): TBytes;
var i, len: Integer;
    sByte: String;
begin
  While Pos(' ', hex) > 0 do
    Delete(hex, Pos(' ', hex), 1);
  len := Length(hex) div 2;
  SetLength(Result, len);
  for i := 0 to len-1 do begin
    sByte := hex[i * 2 + 1] + hex[i * 2 + 2];
    Result[i] := StrToInt('$' + sByte);
  end;
end;

function StrToBytes(s: String): TBytes;
var i, len: Integer;
begin
  len := Length(s);
  SetLength(Result, len);
  for i := 1 to len do begin
    Result[i-1] := Ord(s[i]);
  end;
end;

function InsertBetween(src, substr: String; Spacing: Integer; AtBegin,
  AtEnd: Boolean): String;
var i: Integer;
begin
//src = '1234567890AB'
//substr = ':'
//Result = '12:34:56:78:90:AB' Spacing=2, AtBegin=False, AtEnd=False
//Result = ':12:34:56:78:90:AB:' Spacing=2, AtBegin=True, AtEnd=True
  i := 1;
  while i < Length(src) - Spacing do begin
    If AtBegin and (i = 1) then
      Insert(substr, src, 0);
    Inc(i, Spacing);
    Insert(substr, src, i);
    Inc(i, Length(substr));
  end;
  if AtEnd then
    src := src + substr;
  Result := src;
end;

function IEEE754ByteToFloat(b: array of byte): Single;
var arr: array [0..3] of byte absolute Result;
begin
  //Move(b, arr, 4);
  arr := b;
end;

function SubBytes(srcBytes: array of byte; StartPos, Len: Integer
  ): TBytes;
var i: Integer;
begin
  SetLength(Result, Len);
  for i := StartPos to (StartPos + len-1) do begin
    Result[i-StartPos] := srcBytes[i-1];
  end;
end;

{$ifndef windows}
function EnumerateComport(ShowFriendlyName: Boolean): String;
var fUSB, fSerial, f: String;
    n, status, afile: Integer;
    fstat: stat;
begin
  Result := '';
  n := 0;
  fUSB := 'ttyUSB';
  fSerial := 'ttyS';
  for n := 0 to 99 do begin
    f := Format('/dev/%s%d', [fSerial, n]);
    if FileExists(f) then begin
      afile := fpOpen(f, O_RdOnly or O_NoCtty);
      status := FpFStat(afile, fstat);
      if status = 0 then begin
        status := fstat.st_gid;
        if Result = '' then
          Result := f
        else
          Result := Result + ',' + f;
        fpClose(afile);
      end;

    end else begin
      break;
    end;
  end;

  for n := 0 to 99 do begin
    f := Format('/dev/%s%d', [fUSB, n]);
    if FileExists(f) then begin
      afile := fpOpen(f, O_RdOnly or O_NoCtty);
      status := FpFStat(afile, fstat);
      if status = 0 then begin
        if Result = '' then
          Result := f
        else
          Result := Result + ',' + f;
        fpClose(afile);
      end;
    end else begin
      break;
    end;
  end;

end;

{$else}

function EnumerateComport(ShowFriendlyName: Boolean): String;
var
  reg  : TRegistry;
  l,v  : TStringList;
  n    : integer;
  fn, pn: string;

  function findFriendlyName(key: string; port: string): string;
  var
    r : TRegistry;
    k : TStringList;
    i : Integer;
    ck: string;
    rs: string;
  begin
    r := TRegistry.Create;
    k := TStringList.Create;

    r.RootKey := HKEY_LOCAL_MACHINE;
    r.OpenKeyReadOnly(key);
    r.GetKeyNames(k);
    r.CloseKey;

    try
      for i := 0 to k.Count - 1 do begin
        ck := key + k[i] + '\'; // current key
        // looking for "PortName" stringvalue in "Device Parameters" subkey
        if r.OpenKeyReadOnly(ck + 'Device Parameters') then
        begin
          if r.ReadString('PortName') = port then
          begin
            //Memo1.Lines.Add('--> ' + ck);
            r.CloseKey;
            r.OpenKeyReadOnly(ck);
            rs := r.ReadString('FriendlyName');
            Break;
          end // if r.ReadString('PortName') = port ...
        end  // if r.OpenKeyReadOnly(ck + 'Device Parameters') ...
        // keep looking on subkeys for "PortName"
        else begin// if not r.OpenKeyReadOnly(ck + 'Device Parameters') ...
          if r.OpenKeyReadOnly(ck) and r.HasSubKeys then begin
            rs := findFriendlyName(ck, port);
            if rs <> '' then Break;
          end; // if not (r.OpenKeyReadOnly(ck) and r.HasSubKeys) ...
        end; // if not r.OpenKeyReadOnly(ck + 'Device Parameters') ...
      end; // for i := 0 to k.Count - 1 ...
      result := rs;
    finally
      r.Free;
      k.Free;
    end; // try ...
  end; // function findFriendlyName ...

begin
  v := TStringList.Create;
  l      := TStringList.Create;
  reg    := TRegistry.Create;
  Result := '';

  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then
    begin
      reg.GetValueNames(l);

      for n := 0 to l.Count - 1 do  begin
        pn := reg.ReadString(l[n]);
        fn := findFriendlyName('\System\CurrentControlSet\Enum\', pn);
        if fn = '' then
          fn := pn;
        if ShowFriendlyName then
          v.Add(fn)
        else
          v.Add('\\.\' + pn);
        //v.Add(pn + ' = '+ fn);
      end; // for n := 0 to l.Count - 1 ...

      Result := v.CommaText;
    end; // if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') ...
  finally
    reg.Free;
    v.Free;
    l.Free;
  end; // try ...
end;
{$endif}


function CRC_LINBusClassic(data: array of byte; Len: Integer): TBytes;
var i,start, crc: word;
begin
  if Len < 3 then
    Exit;
  SetLength(Result, 1);
  if data[0] = $55 then
    start := 2
  else
    start := 0;
  crc := data[start]; //get first data byte
  for i := Succ(Start) to Len -2 do begin
    crc := crc + data[i];
    if crc > $FF then
      crc := crc - $FF;
  end;
  Result[0] := not crc;
end;

function CRC_LINBusEnhance(data: array of byte; Len: Integer): TBytes;
var i,start, crc: word;
begin
  if Len < 3 then
    Exit;
  SetLength(Result, 1);
  if data[0] = $55 then
    start := 1
  else
    start := 0;
  crc := data[start]; //get first data byte
  for i := Succ(Start) to Len -2 do begin
    crc := crc + data[i];
    if crc > $FF then
      crc := crc - $FF;
  end;
  Result[0] := not crc;
end;

function CRC16_Modbus(data: array of byte; Len: Integer): TBytes;
var i,j, crc: word;
begin
  SetLength(Result, 2);
  crc := $FFFF;
  for i := 0 to Len -1 do begin
    crc := crc xor data[i];
    for j := 0 to 7 do begin
      if crc and 1 = 1 then begin
        crc := crc shr 1;
        crc := crc xor $A001;
      end else begin
        crc := crc shr 1;
      end;
    end;
  end;
  Result[0] := Lo(crc);
  Result[1] := Hi(crc);
end;

function CRC16Swap_Modbus(data: array of byte; Len: Integer): TBytes;
var b: Byte;
begin
  Result := CRC16_Modbus(data, Len);
  b := Result[0];
  Result[0] := Result[1];
  Result[1] := b;
end;

function CRCTesoo(data: array of byte; Len: Integer): TBytes;
var i, crc: word;
begin
  SetLength(Result, 2);
  crc := $FFFF;
  i := 0;
  crc := 0;
  while i < data[2] do begin
    crc := crc + data[2+i];
    Inc(i);
  end;
  Result[0] := Hi(crc);
  Result[1] := Lo(crc);
end;

function MakeModbusFrame(data: String; CRC_Proc: TCrcFunction): TBytes;
var crc: TBytes;
begin
  Result := HexStrToBytes(data);
  if Assigned(CRC_Proc) then begin
    crc := CRC_Proc(Result, Length(Result));
    Result := Result + crc;
  end;
end;

{ TSyncReadTimer }
{$ifdef windows}
procedure TSyncReadTimer.SetInterval(AValue: int64);
begin
  if FInterval = AValue then Exit;
  FInterval := AValue;
end;

{$else}
procedure TSyncReadTimer.SetInterval(AValue: cardinal);
begin
  if FInterval = AValue then Exit;
  FInterval := AValue;
end;
{$endif}

procedure TSyncReadTimer.Execute;
{$ifdef windows}
var aTick, usec: int64;
{$endif}
begin
  while not Terminated do begin
    if not FEnded then begin
      {$ifdef windows}
      QueryPerformanceCounter(aTick);
      aTick := aTick * 1000000; // convert to microseconds
      usec := aTick div FQPFreq;
      if usec > FuSec then begin
        FEnded := True;
        SendSignal;
      end;
      {$else}
      if GetTickCount64 > FTick then begin
        FEnded := True;
        SendSignal;
      end;
      {$endif}
    end;
  end;
end;

constructor TSyncReadTimer.Create(OSSerial: TCustomOSSerial);
begin
  {$ifdef Windows}
  QueryPerformanceFrequency(FQPFreq);
  FuSec := 0;
  {$else}
  FTick := 0;
  {$endif}
  FOSSerial := OSSerial;
  FEnded := True;
  FreeOnTerminate := True;
  Inherited Create(False);
end;

destructor TSyncReadTimer.Destroy;
begin
  inherited Destroy;
end;

procedure TSyncReadTimer.Stop;
begin
  FEnded := True;
end;

procedure TSyncReadTimer.Restart;
begin
  {$ifdef windows}
  QueryPerformanceCounter(FTick);
  FTick := FTick * 1000000; //convert to microseconds
  FuSec := FTick div FQPFreq; //microseconds per tick
  FuSec := FuSec + FInterval;
  {$else}
  FTick := GetTickCount64 + FInterval;
  {$endif}
  FEnded := False;
end;

{$IFDEF WINDOWS}
procedure TSyncReadTimer.SendSignal;
begin
  SetEvent(FOSSerial.FSyncRead.hEvent);
  //If Assigned(FOSSerial.OnReceive) then
  //  FOSSerial.OnReceive(True);
end;
{$ELSE}
procedure TSyncReadTimer.SendSignal;
begin

end;

{$ENDIF}

{ TOSSerialOutThread }

{$ifndef windows}
procedure TOSSerialTxThread.Execute;
begin

end;

{$else}
procedure TOSSerialTxThread.Execute;
var byteWrote, ignore: dword;
    Ovlap: TOVERLAPPED;
    b: TBytes;
    OK: Boolean;
    Len: Integer;
begin
  Ovlap.hEvent := CreateEvent(nil, False, False, nil); //Create Event
  While not Terminated do begin
    if FBeginWrite then begin
      Len := Length(FTXBuffer);
      FillChar(Ovlap, SizeOf(TOverlapped), 0);
      FWroteCount := 0;
      byteWrote := 0;
      OK := WriteFile(FOSSerial.FHndComm, FTXBuffer[0], Len, ignore, @Ovlap);
      Repeat
        if WaitForSingleObject(Ovlap.hEvent, INFINITE) = WAIT_OBJECT_0 then begin
          OK := GetOverlappedResult(FOSSerial.FHndComm, Ovlap, byteWrote, False);
          Inc(Ovlap.Offset, byteWrote);
        end;
        Inc(FWroteCount, byteWrote);
        if Ovlap.Offset = Len then begin
          break;
        end;
        if OK or (GetLastError = ERROR_IO_PENDING) then begin
          OK := WriteFile(FOSSerial.FHndComm, FTXBuffer[Ovlap.Offset], Len, byteWrote, @Ovlap);
          Inc(Ovlap.Offset, byteWrote);
        end;
      until
        FOSSerial.WriteQueue = 0;
      SetLength(FTXBuffer, 0);
      FBeginWrite := False;
    end;
  end;
  CloseHandle(Ovlap.hEvent);
end;
{$endif}

constructor TOSSerialTxThread.Create(OSSerial: TCustomOSSerial);
begin
  FOSSerial := OSSerial;
  Inherited Create(False);
end;

destructor TOSSerialTxThread.Destroy;
begin
  inherited Destroy;
end;

procedure TOSSerialTxThread.Write(data: TBytes; len: Integer);
begin
  if len = 0 then begin
    len := Length(Data);
    SetLength(FTXBuffer, len);
    Move(Data[0], FTXBuffer[0], len);
  end else begin
    SetLength(FTXBuffer, len);
    Move(Data[0], FTXBuffer[0], len);
  end;
  FBeginWrite := True;
end;

{ TSerialTimeouts }

procedure TSerialTimeouts.SetReadInterval(AValue: dword);
begin
  if FReadIntervalTimeout = AValue then Exit;
  FReadIntervalTimeout := AValue;
end;

procedure TSerialTimeouts.SetReadTotalMultiplier(AValue: dword);
begin
  if FReadTotalTimeoutMultiplier = AValue then Exit;
  FReadTotalTimeoutMultiplier := AValue;
end;

procedure TSerialTimeouts.SetReadTotalConstant(AValue: dword);
begin
  if FReadTotalTimeoutConstant = AValue then Exit;
  FReadTotalTimeoutConstant := AValue;
end;

procedure TSerialTimeouts.SetWriteTotalMultiplier(AValue: dword);
begin
  if FWriteTotalTimeoutMultiplier = AValue then Exit;
  FWriteTotalTimeoutMultiplier := AValue;
end;

procedure TSerialTimeouts.SetWriteTotalConstant(AValue: dword);
begin
  if FWriteTotalTimeoutConstant = AValue then Exit;
  FWriteTotalTimeoutConstant := AValue;
end;

constructor TSerialTimeouts.Create;
begin
{$IFNDEF WINDOWS}
  FReadIntervalTimeout := 10;
  FReadTotalTimeoutMultiplier := 2;
  FReadTotalTimeoutConstant := 10;
{$ELSE}
  FReadIntervalTimeout := MAXDWORD; //10;
  FReadTotalTimeoutMultiplier := 0; //2;
  FReadTotalTimeoutConstant := 0; //10;
{$ENDIF}
  FWriteTotalTimeoutMultiplier := 0;
  FWriteTotalTimeoutConstant := 0;
end;

destructor TSerialTimeouts.Destroy;
begin
  inherited Destroy;
end;

{ TOSSerialRxThread }

{$ifndef windows}
procedure TOSSerialRxThread.Execute;
var epfd, nfds: Integer;
    ev: TEPoll_Event;
    events: Array [0..1] of TEPoll_Event;
begin
  epfd := epoll_create(1);
  ev.Events := EPOLLIN;
  ev.Data.fd := FOSSerial.FHndComm;
  epoll_ctl(epfd, EPOLL_CTL_ADD, ev.Data.fd, @ev);
  While not Terminated do begin
    events[0].Data.fd := 0;
    nfds := epoll_wait(epfd, events, 1, -1); //No timeout
    if nfds =-1 then begin
      //Error
    end else if nfds >= 0 then begin
      //SetCommMask(FOSSerial.FHndComm, 0);
      //if (evMask and EV_RXCHAR <> 0) then begin
        //OK := GetOverlappedResult(FOSSerial.FHndComm, Ovlap, bytesRx, False);
        //if OK or (GetLastError = ERROR_IO_PENDING) then begin
      if events[0].data.fd = FOSSerial.FHndComm then
          ProcessEvRxChar;

      //else if (evMask and EV_RXFLAG <> 0) then
      //else if (evMask and EV_TXEMPTY <> 0) then
      //else if (evMask and EV_CTS <> 0) then
      //else if (evMask and EV_DSR <> 0) then
      //else if (evMask and EV_RLSD <> 0) then
      //else if (evMask and EV_BREAK <> 0) then
      //else if (evMask and EV_ERR <> 0) then
      //else if (evMask and EV_RING <> 0) then
      //else if (evMask and EV_PERR <> 0) then
      //else if (evMask and EV_RX80FULL <> 0) then
      //else if (evMask and EV_EVENT1 <> 0) then
      //else if (evMask and EV_EVENT2 <> 0) then
      //
      //evMask := 0;
      //FOSSerial.DoSetCommMask;
    end else begin
      //break;
    end;
  end;
  //Close(ev);
end;


{$else}
procedure TOSSerialRxThread.Execute;
var Ovlap: TOVERLAPPED;
    evMask, event, LastErr, NotUsed, ModemStats: dword;
    events: TWOHandleArray;
    succeed, Pending: Boolean;
begin
  FillChar(Ovlap, SizeOf(TOverlapped), 0);
  Ovlap.hEvent := CreateEvent(nil, True, False, nil); //Create Event
  events[0] := Ovlap.hEvent;  //Read event
  events[1] := FEvEndProcess.hEvent; //End process event

  While not Terminated do begin
    evmask := 0;
    if WaitCommEvent(FOSSerial.FHndComm, evMask, @Ovlap) then begin
      LastErr := GetLastError;
      //if (evMask and EV_RXCHAR <> 1) then begin
        if GetCommModemStatus(FOSSerial.FHndComm, ModemStats) then begin
          if (evMask and EV_CTS <> 0) then begin
            //if (ModemStats and MS_CTS_ON <> 0) then
          end;
          if (evMask and EV_DSR <> 0) then begin
            //if (ModemStats and MS_DSR_ON <> 0) then
          end;
          if (evMask and EV_RLSD <> 0) then begin
            //if (ModemStats and MS_RLSD_ON <> 0) then
          end;
          if (evMask and EV_RING <> 0) then begin
            //if (ModemStats and MS_RING_ON <> 0) then
          end;
        end else begin //Modem not support or function fail
          raise Exception.Create(Format('GetCommModemStatus failed with error: %d', [GetLastError]));
        end;
      //end;
    end else begin
      FSyncReadTimer.Stop;
      LastErr := GetLastError;
      if (LastErr = ERROR_IO_PENDING) then begin
        event := WaitForMultipleObjects(2, @Events, False, INFINITE);
        if event = WAIT_OBJECT_0 then begin //got incoming data
          //FSyncReadTimer.Stop;
          if (evMask and EV_RXCHAR <> 0) then begin
            Pending := True;
            while Pending do begin
              succeed := GetOverlappedResult(FOSSerial.FHndComm, Ovlap, NotUsed, False);
              //if GetOverlappedResult(FOSSerial.FHndComm, Ovlap, NotUsed, False) then begin
              if succeed then begin
                //Operation ended
                ProcessEvRxChar(@Ovlap);
                Pending := False;
                ResetEvent(Ovlap.hEvent);
              end;
              //end else begin
              if not succeed then begin
                LastErr := GetLastError;
                if LastErr = ERROR_IO_INCOMPLETE then begin
                  //Operation still incomplete, allow to loop again
                  Pending := True;
                  Continue;
                end else if LastErr = ERROR_IO_PENDING then begin
                  ProcessEvRxChar(@Ovlap);
                end;
              end;
              if not Pending then begin
                FSyncReadTimer.Restart;
                //If Assigned(FOSSerial.OnReceive) then
                //  FOSSerial.OnReceive(True);
                //SetEvent(FOSSerial.FSyncRead.hEvent);
              end;
            end; //while loop
            //else if (evMask and EV_RXFLAG <> 0) then
            //else if (evMask and EV_TXEMPTY <> 0) then
            //else if (evMask and EV_CTS <> 0) then
            //else if (evMask and EV_DSR <> 0) then
            //else if (evMask and EV_RLSD <> 0) then
            //else if (evMask and EV_BREAK <> 0) then
            //else if (evMask and EV_ERR <> 0) then
            //else if (evMask and EV_RING <> 0) then
            //else if (evMask and EV_PERR <> 0) then
            //else if (evMask and EV_RX80FULL <> 0) then
            //else if (evMask and EV_EVENT1 <> 0) then
            //else if (evMask and EV_EVENT2 <> 0) then
            //
            //evMask := 0;
            //FOSSerial.DoSetCommMask;
          end;
        end else if event = WAIT_OBJECT_0 + 1 then begin //terminate thread signal
          break;
        end;
      end else if (LastErr = ERROR_INVALID_PARAMETER) then begin
        ProcessEvRxChar(@Ovlap);
        ResetEvent(Ovlap.hEvent);
      end else begin
        //ERROR_INVALID_HANDLE
        //raise Exception.Create(Format('Wait failed with error: %d', [LastErr]));
      end;
    end;
  end;
      //Success := ResetEvent(Ovlap^.hEvent);
    //  FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, nil,
    //                LastError, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), FErrorMsg, 32, nil);
  CloseHandle(Ovlap.hEvent);
  CloseHandle(FOSSerial.FHndComm);
  FOSSerial.FHndComm := 0;
end;
{$endif}

{$ifndef windows}
procedure TOSSerialRxThread.ProcessEvRxChar;
begin
  if FOSSerial.ReceiveMode = rmByte then begin
    Repeat
      FOSSerial.ReadByte;
      If Assigned(OnCommEvent) then
        OnCommEvent(etRxChar);
    until
      FOSSerial.ReadQueue <= 0;
  end else begin
    Repeat
      FOSSerial.ReadBuffer;
      sleep(20);
    until
      FOSSerial.ReadQueue <= 0;
    If Assigned(OnCommEvent) then
      OnCommEvent(etRxChar);
  end;
end;

procedure TOSSerialRxThread.ProcessEvRxCharLocal;
var iRead: LongInt;
begin
  iRead := SerRead(FOSSerial.FHndComm, FOSSerial.FRxBuffer[FOSSerial.FRxLength], 1);
  if iRead > 0 then begin
    FOSSerial.FRxLength := FOSSerial.FRxLength + iRead;
    FOSSerial.FRxCounter := FOSSerial.FRxCounter + iRead;
  end;
  If Assigned(OnCommEvent) then
    OnCommEvent(etRxChar);
end;

{$else}
procedure TOSSerialRxThread.ProcessEvRxChar(Ovlap: POVERLAPPED);
begin
  if FOSSerial.ReceiveMode = rmByte then begin
    Repeat
      FOSSerial.ReadByte(Ovlap^);
      If Assigned(OnCommEvent) then
        OnCommEvent(etRxChar);
    until
      FOSSerial.ReadQueue <= 0;
  end else begin
    Repeat
      FOSSerial.ReadBuffer(ovlap^);
      Sleep(1);
    until
      FOSSerial.ReadQueue <= 0;
    If Assigned(OnCommEvent) then
      OnCommEvent(etRxChar);
  end;
end;
{$endif}

constructor TOSSerialRxThread.Create(OSSerial: TCustomOSSerial);
begin
  FOSSerial := OSSerial;
  FSyncReadTimer := TSyncReadTimer.Create(OSSerial);
  {$ifdef windows}
  FSyncReadTimer.SetInterval(1); //default to 1 microsec
  {$else}
  FSyncReadTimer.SetInterval(1); //default to 1 msec
  {$endif}
  FSyncReadTimer.FreeOnTerminate := True;
  {$ifndef windows}

  {$else}
  FEvEndProcess.hEvent := CreateEvent(nil, True, False, nil); //Create Event
  {$endif}
  Inherited Create(True);
end;

destructor TOSSerialRxThread.Destroy;
begin
  Terminate;
  {$ifndef windows}

  {$else}
  CloseHandle(FEvEndProcess.hEvent);
  {$endif}
  FSyncReadTimer.Terminate;
  //FSyncReadTimer.Free;
  Inherited Destroy;
end;

{ TCustomOSSerial }

{$ifndef windows}
function TCustomOSSerial.DoSetCommMask: Boolean;
begin

end;

{$else}
function TCustomOSSerial.DoSetCommMask: Boolean;
begin
  Result := SetCommMask(FHndComm, DoGetCommMask);
end;
{$endif}

function TCustomOSSerial.ArgumentCount(s: String): Integer;
begin
  //protocol = $01,$03,$04,%1:4,C:2;

  //eg. 01 03 04 11 22 33 44 C5 D6
  //    $  $  $  %:4         c:2
  Result := 0;
  while Pos(':%', s) > 0 do
    Delete(s, Pos(':%', s), 2);
  while Pos('%', s) > 0 do begin
    Inc(Result);
    Delete(s, Pos('%', s), 1);
  end;
end;

function TCustomOSSerial.GetBaudRate: dword;
begin
  Result := FDCB.BaudRate;
end;

function TCustomOSSerial.GetByteSize: byte;
begin
  Result := FDCB.ByteSize;
end;

function TCustomOSSerial.GetNodeCount: Integer;
begin
  Result := FNodeList.Count;
end;


function TCustomOSSerial.GetPortName: String;
//var s: string;
//    i: Integer;
begin
  //s := FPortName;
  //i := Pos('\\.\', s);
  //if i > 0 then
  //  Delete(s, i, 4)
  //else
  //  s := FPortName;
  Result := FPort;
end;

function TCustomOSSerial.GetSyncReadStatus: Boolean;
begin
  Result := not FCommThread.FSyncReadTimer.Ended;
end;

function TCustomOSSerial.ProtocolCount(s: String): Integer;
var tmp: String;
    x: Integer;
begin
  //protocol = $01,$03,$04,%1:4,C:2;
  //eg. 01 03 04 11 22 33 44 C5 D6
  //    $  $  $  %:4         c:2
  Result := 0;
  while Pos(':%', s) > 0 do
    Delete(s, Pos(':%', s), 2);
  while Pos(',', s) > 0 do begin
    tmp := Copy(s, 1, Pos(',',s)-1);
    Delete(s, 1, Pos(',', s));
    if Trim(tmp) = '' then Exit;
    if (tmp[1]='$') or (tmp[1]='#') then begin
      Inc(Result);
    end else if (tmp[1]='%') or (LowerCase(tmp[1])='c') then begin
      tmp := Copy(tmp, Pos(':', tmp)+1, Length(tmp)-Pos(':',tmp));
      x := StrToIntDef(tmp, -1);
      if x > 0 then
        Inc(Result, x);
    end;
  end;
  if Pos(';', s) > 0 then begin
    tmp := Copy(s, 1, Pos(';',s)-1);
    Delete(s, 1, Pos(';', s));
    if Trim(tmp) = '' then Exit;
    if (tmp[1]='$') or (tmp[1]='#') then begin
      Inc(Result);
    end else if (tmp[1]='%') or (LowerCase(tmp[1])='c') then begin
      tmp := Copy(tmp, Pos(':', tmp)+1, Length(tmp)-Pos(':',tmp));
      x := StrToIntDef(tmp, -1);
      if x > 0 then
        Inc(Result, x);
    end;
  end;
end;

function TCustomOSSerial.DecodeProtocol(var b: TBytes; protocol: String; var ProtocolData: TProtocolData): boolean;
var token: String;
    cnt, i, offset, value: Integer;
    Finished: Boolean;
const argidx: Integer = 0;
      idx: Integer = 0;
begin
  if Pos(';', protocol) = 0 then Exit;
  token := '';
  Result := False;
  Finished := False;
  token := Copy(protocol, 1, Pos(',', protocol)-1);
  if argidx = 0 then begin
    SetLength(ProtocolData.DataArray[argidx] {arg[argidx]}, length(b));
    move(b[0], ProtocolData.DataArray{arg}[argidx][0], FProtocolCount);
    Inc(argIdx);
  end;
  if token = '' then begin
    token := Copy(protocol, 1, Pos(';', protocol)-1);
    Delete(protocol, 1, Pos(';', protocol));
    if Trim(token) = '' then begin
      argidx := 0;
      idx := 0;
      Exit;
    end;
    Finished := True;
  end else begin
    Delete(protocol, 1, Pos(',', protocol));
  end;
  if (token[1] = '''') then begin //string
    while Pos('''', token) > 0 do
      Delete(token, Pos('''', token), 1); //delete all '
    cnt := Length(token);
    offset := cnt;
    if cnt > 0 then begin
      if idx < Length(b) then begin
        i := 1;
        while cnt > 0 do begin
          if b[idx+Pred(i)] = Ord(token[i]) then begin
            Inc(i);
            Dec(cnt);
          end else begin
            argidx := 0;
            idx := 0;
            Result := False;
            Exit;
          end;
        end;
        if not Finished then begin
          idx := idx + offset;
          Result := DecodeProtocol(b, protocol, ProtocolData);//arg, checksum);
        end else begin
          Result := True;
          idx := 0;
        end;
      end else begin
        Result := False;
        idx := 0;
      end;
    end;
  end else if (token[1] = '$') or (token[1] = '#')
    {(token[1] in ['0'..'9','A'..'F','a'..'f'])} then begin
    if (token[1] = '#') then
      Delete(token, 1, 1)
    else if (token[1] <> '$') then
      Insert('$', token, 1);
    value := StrToIntDef(token, -1);
    if b[idx] = value then begin
      if idx < Length(b) then begin
        if not Finished then begin
          idx := idx + 1;
          Result := DecodeProtocol(b, protocol, ProtocolData);//arg, checksum);
        end else begin
          Result := True;
          idx := 0;
        end;
      end else begin
        Result := False;
        idx := 0;
      end;
    end else begin
      argidx := 0;
      idx := 0;
      Result := False;
      exit;
    end;
  end else if LowerCase(token[1]) = 'c' then begin
    cnt := StrToIntDef(Copy(token, POs(':', token)+1, Length(token) - Pos(':', token)), -1);
    offset := cnt;
    ProtocolData.ChecksumSize := cnt;
    if cnt = 1 then begin
      ProtocolData.Checksum := b[idx];
    end else if cnt = 2 then begin
      ProtocolData.Checksum := (b[idx] * 256) + b[idx+1];
    end;
    if idx+Pred(cnt) < Length(b) then begin
      if not Finished then begin
        idx := idx + offset;
        Result := DecodeProtocol(b, protocol, ProtocolData);//arg, checksum);
      end else begin
        Result := True;
        idx := 0;
      end;
    end else begin
      Result := False;
      idx := 0;
    end;
  end else if token[1] = '%' then begin
    cnt := StrToIntDef(Copy(token, POs(':', token)+1, Length(token) - Pos(':', token)), -1);
    offset := cnt;
    if cnt > 0 then begin
      SetLength(ProtocolData.DataArray{arg}[argidx], cnt);
      if idx+Pred(cnt) < Length(b) then begin
        i := 0;
        while cnt > 0 do begin
          ProtocolData.DataArray{arg}[argidx][i] := b[idx+i];
          Inc(i);
          Dec(cnt);
        end;
        Inc(argidx);
        if not Finished then begin
          idx := idx + offset;
          Result := DecodeProtocol(b, protocol, ProtocolData)//arg, checksum);
        end else begin
          Result := True;
          idx := 0;
        end;
      end else begin
        Result := False;
        idx := 0;
      end;
    end;
  end;
  if Finished then begin
    argidx := 0;
    idx := 0;
  end;
end;

{$IFNDEF WINDOWS}
function TCustomOSSerial.DoGetCommMask: dword;
begin

end;

function TCustomOSSerial.GetParity: TParityType;
begin
  Result := TParityType(FDCB.Parity);
end;

{$ELSE}
function TCustomOSSerial.DoGetCommMask: dword;
begin
  Result := 0;
  if evRXCHAR in FEvMask then
    Result := Result + EV_RXCHAR;
  if evRXFLAG in FEvMask then
    Result := Result + EV_RXFLAG;
  if evTXEMPTY in FEvMask then
    Result := Result + EV_TXEMPTY;
  if evCTS in FEvMask then
    Result := Result + EV_CTS;
  if evDSR in FEvMask then
    Result := Result + EV_DSR;
  if evRLSD in FEvMask then
    Result := Result + EV_RLSD;
  if evBREAK in FEvMask then
    Result := Result + EV_BREAK;
  if evERR in FEvMask then
    Result := Result + EV_ERR;
  if evRING in FEvMask then
    Result := Result + EV_RING;
  if evPERR in FEvMask then
    Result := Result + EV_PERR;
  if evRX80FULL in FEvMask then
    Result := Result + EV_RX80FULL;
  if evEVENT1 in FEvMask then
    Result := Result + EV_EVENT1;
  if evEVENT2 in FEvMask then
    Result := Result + EV_EVENT2;
end;

function TCustomOSSerial.GetParity: TParity;
begin
  //Result := TParityType(FDCB.Parity);
  Result := TParity(FDCB.Parity);
end;

{$ENDIF}

function TCustomOSSerial.GetStopBits: TStopBits;
begin
  {$ifndef windows}
  Result := TStopBits(FDCB.StopBits);
  {$else}
  Result := TStopBits(FDCB.StopBits);
  {$endif}
end;

procedure TCustomOSSerial.DoRxThreadCommEvent(EventType: TEventType);
var bTemp: Tbytes;
    bTempLen: Integer;
begin
  //try
    //EnterCriticalsection(FCS);
    Case EventType of
      etRxChar: begin
        {$ifndef windows}
        RTLeventSetEvent(FSyncRead);
        {$else}
        //if GetTickCount > timeout + FTimeouts.ReadByteInterval then begin
        //  if ReadQueue = 0 then
  //          SetEvent(FSyncRead.hEvent);
        //end;
        {$endif}
        //bTempLen := PeekBuf(bTemp);
        //sleep(1); //needed give more time to Rx Thread
        if not FSkipOnReceive then begin
          if Assigned(OnReceive) then begin
            //OnReceive(False);
            OnReceive(Self);
          end;
        end else begin
          FSkipOnReceive := False;
        end;
        //if Assigned(FOnDebug) then begin
          //if not (csDesigning in ComponentState) then begin
            //if bTempLen > 0 then begin
            //  FDebugRx.Insert(0, BytesToHexStr(bTemp, bTempLen, True));
            //end;
            //FOnDebugRx(Self);
          //FOnDebug(bTemp, bTempLen, ddIn);
          //end;
        //end;
      end;
    end;
  //finally
  //  LeaveCriticalsection(FCS);
  //end;
end;


procedure TCustomOSSerial.SetDataBits(AValue: byte);
{$ifndef windows}
var Flags: TSerialFlags;
{$endif}
begin
  if FDCB.ByteSize = AValue then
    Exit;
  FDCB.ByteSize := AValue;
{$ifndef windows}
  Flags := [];
  SerSetParams(FHndComm, FDCB.Baudrate, FDCB.Bytesize, TParityType(FDCB.Parity),
                         FDCB.Stopbits, Flags);
{$endif}
end;


procedure TCustomOSSerial.SetBaudrate(AValue: dword);
{$ifndef windows}
var Flags: TSerialFlags;
{$else}
//var succeed: boolean;
{$endif}
begin
  if FDCB.BaudRate = AValue then Exit;
  FDCB.BaudRate := AValue;

  {$ifndef windows}
    Flags := [];
    SerSetParams(FHndComm, FDCB.Baudrate, FDCB.Bytesize, TParityType(FDCB.Parity),
                           FDCB.Stopbits, Flags);
  {$else}
     //succeed := SetCommState(FHndComm, @FDCB);
  {$endif}
end;

{$ifndef windows}
procedure TCustomOSSerial.SetEnabled(AValue: Boolean);
var Flags: TSerialFlags;
begin
  if FEnabled=AValue then Exit;
  FEnabled:=AValue;
  if (csDesigning in ComponentState) then Exit;
  if FEnabled then begin //Open port
    InitCriticalSection(FCS);
    SetLength(FRxBuffer, FRxBufSize);
    FCommThread := TOSSerialRxThread.Create(Self);
    FCommThread.FreeOnTerminate := True;
    FCommThread.OnCommEvent := @DoRxThreadCommEvent;
    FHndComm := SerOpen(FPort);
    Flags := [];
    SerSetParams(FHndComm, FDCB.Baudrate, FDCB.Bytesize, TParityType(FDCB.Parity),
                           FDCB.Stopbits, Flags);

    if FHndComm <= 0 then
      FEnabled := False
    else
      FCommThread.Start;
//    OK := GetCommMask(FHndComm, FEventMask);
  end else begin
    //RTLeventSetEvent(FSyncRead);
    FCommThread.Terminate;
    //RTLeventdestroy(FSyncRead);
    FRxLength := 0;
    Sleep(200);
    SerClose(FHndComm);
    SetLength(FRxBuffer, 0);
    DoneCriticalsection(FCS);
  end;
end;

{$else}
procedure TCustomOSSerial.SetEnabled(AValue: Boolean);
var Succeed: Boolean;
    aDCB: TDCB;
    comTimeout: TCOMMTIMEOUTS;
    ErrorCode: dword;
    evnt: TNotifyEvent;
begin
  if FEnabled=AValue then Exit;
  FEnabled:=AValue;
  Succeed := False;
  //if csDesigning in ComponentState then Exit;
  if FEnabled then begin //Open port
    //InitCriticalSection(FCS);
    FSkipOnReceive := False;
    ResetCounters(True, True);
    ClearBuffer(True, True);
    SetLength(FRxBuffer, FRxBufSize);
    Try
      FHndComm := CreateFile(PChar('\\.\' + FPort),
                             GENERIC_READ or GENERIC_WRITE,
                             0,                             //exclusive access
                             nil,                           //no security attrb
                             OPEN_EXISTING,
                             FILE_FLAG_OVERLAPPED or FILE_ATTRIBUTE_SYSTEM,
                             0);
      if FHndComm = INVALID_HANDLE_VALUE then begin
        ErrorCode := GetLastError;
        FEnabled := False;
        raise Exception.Create('Open COM port failed.' + #13#10 + 'Error code: ' + IntToStr(ErrorCode) + #$D#$A +
                   SysErrorMessage(ErrorCode));
        //MessageDlg('Open COM port failed.' + #13#10 + 'Error code: ' + IntToStr(ErrorCode) + #$D#$A +
                   //SysErrorMessage(ErrorCode) , mtError, [mbOk], 0);
        //Exit;
      end;
      Succeed := SetupComm(FHndComm, FRxBufSize, FTxBufSize); //must be first call after CreateFile

      Succeed := GetCommState(FHndComm, aDCB); //load default values
      if not Succeed then begin
        ErrorCode := GetLastError;
        CloseHandle(FHndComm);
        FEnabled := False;
        raise Exception.Create('Get COMSTATE failed.' + #13#10 + 'Error code: ' + IntToStr(ErrorCode) + #$D#$A +
                               SysErrorMessage(ErrorCode));
        //MessageDlg('Get COMSTATE failed.' + #13#10 + 'Error code: ' + IntToStr(ErrorCode) + #$D#$A +
        //           SysErrorMessage(ErrorCode), mtError, [mbOk], 0);
        //Exit;
      end;
      aDCB.BaudRate := Integer(Baudrate);
      aDCB.Parity := Integer(Parity);
      aDCB.StopBits := Integer(StopBits);
      aDCB.ByteSize := DataBits;
      //Not working...
      //aDCB.EvtChar := #$A;
      //aDCB.EofChar := #$D;
      FDCB := aDCB;
      Succeed := SetCommState(FHndComm, aDCB);

  //      Totaltimeout = (Multiplier * No. of Bytes) + Constant

      comTimeout.ReadIntervalTimeout := Timeouts.ReadByteInterval;          //interval timeout between bytes
      comTimeout.ReadTotalTimeoutConstant := Timeouts.ReadConstant;
      comTimeout.ReadTotalTimeoutMultiplier := Timeouts.ReadByteMultiplier;
      comTimeout.WriteTotalTimeoutConstant := Timeouts.WriteConstant;
      comTimeout.WriteTotalTimeoutMultiplier := Timeouts.WriteByteMultiplier;
      Succeed := SetCommTimeouts(FHndComm, comTimeout);

        //Success := SetCommMask(FHndComm, EV_RXCHAR);
        //FReadThread.FEventMask := FEventMask;
      Succeed := PurgeComm(FHndComm, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
      //Succeed := GetCommMask(FHndComm, FEventMask);
      if MonitorEvents <> [] then begin
        Succeed := DoSetCommMask;
      end;

      {$ifndef windows}
      FSyncRead := RTLEventCreate;
      RTLeventResetEvent(FSyncRead);
      {$else}
      FillChar(FSyncRead, SizeOf(TOVERLAPPED), 0);
      //FSyncRead.hEvent := CreateEvent(nil, False, False, nil); //autoreset
      FSyncRead.hEvent := CreateEvent(nil, True, False, nil); //manual reset
      ResetEvent(FSyncRead.hEvent);
      {$endif}
      FCommThread := TOSSerialRxThread.Create(Self);
      FCommThread.FreeOnTerminate := True;
      FCommThread.OnCommEvent := @DoRxThreadCommEvent;
      FCommThread.Suspended := False;

      //EscapeCommFunction(FHndComm, SETRTS);
      EscapeCommFunction(FHndComm, CLRRTS);

      //EscapeCommFunction(FHndComm, SETDTR);
      EscapeCommFunction(FHndComm, CLRDTR);

      //EscapeCommFunction(FHndComm, SETRTS);
      //EscapeCommFunction(FHndComm, SETDTR);
      SyncRead(1); //needed to fix a bug with first syncread() not receiving data but letting data slip to OnReceive event.
    except
      if FHndComm <> INVALID_HANDLE_VALUE then
        CloseHandle(FHndComm);
      CloseHandle(FSyncRead.hEvent);
      if Assigned(FCommThread) then begin
        SetEvent(FCommThread.FEvEndProcess.hEvent);
        Succeed := CancelIO(FHndComm);
        Succeed := PurgeComm(FHndComm, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
        FCommThread.Terminate;
        Sleep(200);
      end;
      raise;
      //DoneCriticalsection(FCS);
    end;
    //FWriteThread := TOSSerialTxThread.Create(Self);
    //FWriteThread.FreeOnTerminate := True;
  end else begin  //Close port
    //if FHndComm <> INVALID_HANDLE_VALUE then
    //  CloseHandle(FHndComm);
    evnt := FOnReceive;
    FOnReceive := nil;
    CloseHandle(FSyncRead.hEvent);
    if Assigned(FCommThread) then begin
      SetEvent(FCommThread.FEvEndProcess.hEvent);
      Succeed := CancelIO(FHndComm);
      Succeed := PurgeComm(FHndComm, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
      FCommThread.Terminate;
      Sleep(200);
    end;
    ClearBuffer(True, True);
    FOnReceive := evnt;
    //DoneCriticalsection(FCS);
  end;
end;
{$endif}

procedure TCustomOSSerial.SetEvMask(AValue: TEvMask);
begin
  if FEvMask = AValue then Exit;
  FEvMask := AValue;
  DoSetCommMask;
end;

{$IFDEF WINDOWS}
procedure TCustomOSSerial.SetParity(AValue: TParity);
begin
  if FDCB.Parity = Integer(AValue) then
    Exit;
  FDCB.Parity := Integer(AValue);
end;

{$ELSE}
procedure TCustomOSSerial.SetParity(AValue: TParityType);
var Flags: TSerialFlags;
begin
  if FDCB.Parity = Integer(AValue) then
    Exit;
  FDCB.Parity := Integer(AValue);
  Flags := [];
  SerSetParams(FHndComm, FDCB.Baudrate, FDCB.Bytesize, TParityType(FDCB.Parity),
                         FDCB.Stopbits, Flags);
end;

{$ENDIF}

procedure TCustomOSSerial.SetPortName(AValue: String);
var s: String;
    i,j: Integer;
begin
  AValue := ReplaceText(AValue, '\\.\', '');
  if Length(AValue) >= 5 then begin
    s := AValue;
    i :=  Pos('(', s);
    j := Pos(')', s);
    if (i > 0) and (j > i) then begin
      s := Copy(s, i+1, j-i-1);
    end else begin
      s := AValue;
    end;
  end else begin
    s := AValue;
  end;
  if FPort = s then Exit;
  if FEnabled then
    raise Exception.Create('Cannot change port while port opened.');
  FPort := s;
end;

procedure TCustomOSSerial.SetProtocol(AValue: String);
var i: Integer;
    isHead: Boolean;
    token: String;
    v: dword;
begin
  if FProtocol = AValue then Exit;
  FProtocol := AValue;
  FProtocolCount := ProtocolCount(FProtocol);
  //isHead := True;
  //FHeader := '';
  //i := 1;
  //while AValue <> '' do begin
  //  token := Copy(AValue, 1, Pos(',', AValue)-1);
  //  Delete(AValue, 1, Pos(',', AValue));
  //  if (token[1] = '$') or (token[1] = '#') or (token[1] = '''') then begin
  //
  //    FHeader := FHeader + AValue[i];
  //
  //  end;
  //end;
end;

procedure TCustomOSSerial.SetRxBufSize(AValue: dword);
begin
  if FRxBufSize = AValue then Exit;
  FRxBufSize := AValue;
end;

procedure TCustomOSSerial.SetRxMode(AValue: TReceiveMode);
begin
  if FRxMode = AValue then Exit;
  FRxMode := AValue;
end;

procedure TCustomOSSerial.SetStopBits(AValue: TStopbits);
{$ifndef windows}
var Flags: TSerialFlags;
{$endif}
begin
  if FDCB.StopBits = Integer(AValue) then Exit;
  FDCB.StopBits := Integer(AValue);
{$ifndef windows}
  Flags := [];
  SerSetParams(FHndComm, FDCB.Baudrate, FDCB.Bytesize, TParityType(FDCB.Parity),
                         FDCB.Stopbits, Flags);
{$endif}
end;

procedure TCustomOSSerial.SetTxBufSize(AValue: dword);
begin
  if FTxBufSize = AValue then Exit;
  FTxBufSize := AValue;
end;


{$ifndef windows}
procedure TCustomOSSerial.ReadBuffer;
var iRead: LongInt;
begin
  iRead := SerRead(FHndComm, FRxBuffer[FRxLength], ReadQueue);
  if iRead > 0 then begin
    FRxLength := FRxLength + iRead;
    FRxCounter := FRxCounter + iRead;
  end;
  if Assigned(FOnDebug) then
    FOnDebug(FRxBuffer, FRxLength, ddIn);
end;
{$else}
procedure TCustomOSSerial.ReadBuffer(ovlap: TOVERLAPPED);
var ignore: dword = 0;
begin
  ReadFile(FHndComm, FRxBuffer[FRxLength], ReadQueue, ignore, @Ovlap);
  FRxLength := FRxLength + Ovlap.InternalHigh;
  FRxCounter := FRxCounter + Ovlap.InternalHigh;
end;
{$endif}

{$ifndef windows}
procedure TCustomOSSerial.ReadByte;
var iRead: LongInt;
begin
  iRead := SerRead(FHndComm, FRxBuffer[FRxLength], 1);
  if iRead > 0 then begin
    FRxLength := FRxLength + iRead;
    FRxCounter := FRxCounter + iRead;
  end;
  if Assigned(FOnDebug) then
    FOnDebug(FRxBuffer, FRxLength, ddIn);
end;

{$else}
procedure TCustomOSSerial.ReadByte(ovlap: TOVERLAPPED);
var ignore: dword;
begin
  ReadFile(FHndComm, FRxBuffer[FRxLength], 1, ignore, @Ovlap);
  FRxLength := FRxLength + Ovlap.InternalHigh;
  FRxCounter := FRxCounter + Ovlap.InternalHigh;
end;
{$endif}

procedure TCustomOSSerial.AddToNodeList(Node: TOSModbusRTUObject);
begin
  FNodeList.Add(Node);
end;

procedure TCustomOSSerial.DeleleFromNodeList(Node: TOSModbusRTUObject);
var i: Integer;
begin
  i := FNodeList.IndexOf(Node);
  if i >= 0 then begin
    FNodeList.Delete(i);
  end;
end;


function TCustomOSSerial.SyncRead(Timeout: cardinal=500): Boolean;
var event: dword;
    LastMode: TReceiveMode;
    //SavedEvent: TReceiveEvent;
    SavedEvent: TNotifyEvent;
    t1, t2: qword;
    r: cardinal;
begin
  if not FEnabled then
    raise Exception.Create('Port not open.');
{$IFDEF WINDOWS}
  //ResetEvent(FSyncRead.hEvent);
{$ELSE}
  RTLeventResetEvent(FSyncRead);
{$ENDIF}
  FSkipOnReceive := True;
  SavedEvent := OnReceive;
  OnReceive := nil;
  Result := False;
  LastMode := ReceiveMode;
  ReceiveMode := rmBuffer;
{$ifndef windows}
  t1 := GetTickCount64;
  RTLeventWaitFor(FSyncRead, Timeout);
  t2 := GetTickCount64;
  r := t2 - t1;
  if r >= Timeout then
    FRxLength := 0
  else
    Result := True;
  RTLeventResetEvent(FSyncRead);
{$else}
  event := WaitForSingleObject(FSyncRead.hEvent, Timeout);
  if event = WAIT_OBJECT_0 then begin
    Result := True;
  end else if event = WAIT_TIMEOUT then begin
    FRxLength := 0;
  end;
{$endif}
  ReceiveMode := LastMode;
  OnReceive := SavedEvent;
end;

{$IFDEF WINDOWS}
function TCustomOSSerial.AsyncRead(var BytesRead: word; out Timeout: Boolean): Boolean;
{$ELSE}
function TCustomOSSerial.AsyncRead(var BytesRead: word; out Timeout: cardinal): Boolean;
{$ENDIF}
const Finished: Boolean = True;
      i: Integer = 0;
var event: dword;
    LastMode: TReceiveMode;
{$IFNDEF WINDOWS}
    t1, t2: qword;
    r: cardinal;
{$ENDIF}
begin
  FSkipOnReceive := True;
  Result := False;
  if Finished then begin
    LastMode := ReceiveMode;
    ReceiveMode := rmBuffer;
    Finished := False;
  end;
{$ifndef windows}
  t1 := GetTickCount64;
  RTLeventWaitFor(FSyncRead, Timeout);
  t2 := GetTickCount64;
  r := t2 - t1;
  if r >= Timeout then
    FRxLength := 0
  else
    Result := True;
  RTLeventResetEvent(FSyncRead);
{$else}
  event := WaitForSingleObject(FSyncRead.hEvent, 100);
  if event = WAIT_OBJECT_0 then begin
    Result := True;
    ReceiveMode := LastMode;
    Finished := True;
    Timeout := False;
  end else if event = WAIT_TIMEOUT then begin
    if Assigned(FOwner) then begin
      With FOwner as TForm do begin
        Application.ProcessMessages;
      end;
    end;
    if BytesRead = RxLength then begin
      Inc(i); //inc 5 times is equal to 500ms timeout
      if i >= 5 then begin
        ReceiveMode := LastMode;
        Finished := True;
        Timeout := True;
        Result := True;
      end;
    end else begin
      i := 0;
    end;
  end;
  BytesRead := RxLength;
{$endif}
end;

constructor TCustomOSSerial.Create(AOwner: TComponent);
var ports: TStringList;
    i: Integer;
begin
  Inherited Create(AOwner);
  FVersion := ver;
  FOwner := AOwner;
  FPort := '';
  FillChar(FDCB, SizeOf(FDCB), 0);
//  FDCB.DCBlength := SizeOf(FDCB);
  FDCB.BaudRate := 9600;
  FDCB.ByteSize := 8;
  FDCB.StopBits := Integer(ONESTOPBIT);
{$IFDEF WINDOWS}
  FDCB.Parity := Integer(NOPARITY);
{$ELSE}
  FDCB.Parity := Integer(NoneParity);
{$ENDIF}
  FEvMask := [evRXCHAR, evRXFLAG, evTXEMPTY, evCTS, evDSR,
             evRLSD, evBREAK, evERR, evRING, evPERR,
             evRX80FULL, evEVENT1, evEVENT2];
  //FEventMask := 0;
  FTimeouts := TSerialTimeouts.Create;
  FRxBufSize := 1024;
  FTxBufSize := 1024;
  //SetLength(FRxBuffer, FRxBufSize);
  //SetLength(FProtocolBuffer, 0);
  FRxLength := 0;
  FNodeList := TList.Create;
  FRxMode := rmBuffer;
  {$IFNDEF WINDOWS}
  FSyncRead := RTLEventCreate;
  RTLEventResetEvent(FSyncRead);
  {$ENDIF}
end;

destructor TCustomOSSerial.Destroy;
begin
  {$ifndef windows}
  if FHndComm > 0 then begin
    SerFlushInput(FHndComm);
    SerFlushOutput(FHndComm);
  end;
  {$else}
  if FHndComm > 0 then
    PurgeComm(FHndComm, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
  {$endif}
  if FEnabled then
    Enabled := False;
  SetLength(FRxBuffer, 0);
  SetLength(FProtocolBuffer, 0);
  FTimeouts.Free;
  Sleep(200);
  {$ifndef windows}
  RTLEventDestroy(FSyncRead);
  {$endif}
  FNodeList.Clear;
  FNodeList.Free;
  Inherited Destroy;
end;

procedure TCustomOSSerial.Loaded;
begin
  inherited Loaded;
  if Enabled then begin
    Enabled := False;
    Enabled := True;
  end;
end;

function TCustomOSSerial.ReadBuf(out Buf; BytesToRead: word; ATimeout: word
  ): Integer;
var ticknow: cardinal;
    timeout: boolean;
    byteread: word;
begin
  if not FEnabled then
    raise Exception.Create('Port not open.');
  timeout := false;
  ticknow := GetTickCount;
  while BytesToRead > FRxLength do begin
    if Assigned(FOwner) then begin
      With FOwner as TForm do begin
        Application.ProcessMessages;
      end;
    end;
    if GetTickCount > ticknow + ATimeout then begin
      timeout := true;
      break;
    end;
  end;
  if timeout then
    byteread := FRxLength
  else
    byteread := BytesToRead;
  SetLength(TBytes(Buf), byteread);
  Move(FRxBuffer[0], TBytes(Buf)[0], byteread);
  Result := byteread;
  FRxLength := FRxLength - byteread;
end;

function TCustomOSSerial.ReadBuf(out Buf): Integer;
begin
  if not FEnabled then
    raise Exception.Create('Port not open.');
  //EnterCriticalsection(FCS);
  SetLength(TBytes(Buf), FRxLength);
  Move(FRxBuffer[0], TBytes(Buf)[0], FRxLength);
  Result := FRxLength;
  FRxLength := 0;
  //LeaveCriticalSection(FCS);
end;

function TCustomOSSerial.Read(out Buf): Integer;
begin
  Result := ReadBuf(Buf);
end;

function TCustomOSSerial.ReadProtocolBuf(var Buf: TProtocolData): Integer;
var tmpBuf: TBytes;
    bufSize, argcnt: Integer;
begin
  if (ReceiveMode = rmByte) or (ReceiveMode = rmBuffer) then begin
    Result := 0;
    FRxLength := 0;
  end else if (ReceiveMode = rmProtocol) then begin
  //==Protocol used =====================================
    SetLength(TmpBuf, FRxLength);
    Move(FrxBuffer[0], tmpBuf[0], FRxLength);
    FProtocolBuffer := FProtocolBuffer + tmpBuf;
    bufsize := Length(FProtocolBuffer);
    if (FProtocolCount > 0) and (bufSize >= FProtocolCount) then begin
      argcnt := ArgumentCount(Fprotocol);
      SetLength(TProtocolData(Buf).DataArray, argcnt + 1); //add another arg for original frame msg
      if DecodeProtocol(FProtocolBuffer, Fprotocol, Buf) then begin
        //if Assigned(OnProtocol) then
        //  OnProtocol(barr, chksum);
        FRxLength := 0;
      end;
      SetLength(FProtocolBuffer, 0);
    end else if FProtocolCount = 0 then begin
      SetLength(FProtocolBuffer, 0);
    end;
  end;
  //=======================================================
end;

function TCustomOSSerial.ReadString: String;
var len: Integer;
    b: TBytes;
begin
  len := ReadBuf(b);
  Result := TEncoding.Ansi.GetString(b);
  //Result := BytesToAsciiStr(b, len);
end;

function TCustomOSSerial.ReadStr: String;
begin
  Result := ReadString;
end;

function TCustomOSSerial.ReadData: String;
begin
  Result := ReadString;
end;

function TCustomOSSerial.ReadBufAsHexStr: String;
var len: Integer;
    b: TBytes;
begin
  len := ReadBuf(b);
  Result := BytesToHexStr(b, Length(b), True);
  //Result := TEncoding.Ansi.GetString(b);
end;

function TCustomOSSerial.PeekBuf(out Buf): Integer;
begin
  SetLength(TBytes(Buf), FRxLength);
  Move(FRxBuffer[0], TBytes(Buf)[0], FRxLength);
  Result := FRxLength;
end;


{$ifndef windows}
function TCustomOSSerial.WriteBuf(const Buf; len: Integer = 0): Integer;
var ignore: dword;
    b: TBytes;
begin
  //RTLeventResetEvent(FSyncRead);
  if not FEnabled then begin
    raise Exception.Create('Port not open.');
    Exit;
  end;
  if len = 0 then begin
    len := Length(TBytes(Buf));
    SetLength(b, len);
    Move(TBytes(Buf)[0], b[0], len);
  end else begin
    SetLength(b, len);
    Move(Buf, b[0], len);
  end;
  FTxCounter := FTxCounter + len;
  Result := SerWrite(FHndComm, b[0], Len);
  if Assigned(FOnDebug) then
    FOnDebug(b, Len, ddOut);
end;

{$else}
procedure TCustomOSSerial.WriteBuf(const Buf; len: Integer = 0);
var byteWrote, ignore: dword;
    Ovlap: TOVERLAPPED;
    b: TBytes;
    Succeed: Boolean;
    i: Integer;
begin
  ResetEvent(FSyncRead.hEvent);
  if not FEnabled then begin
    raise Exception.Create('Port not open.');
    Exit;
  end;
  if len = 0 then begin
    len := Length(TBytes(Buf));
    SetLength(b, len);
    Move(TBytes(Buf)[0], b[0], len);
  end else begin
    SetLength(b, len);
    Move(Buf, b[0], len);
  end;
  FTxCounter := FTxCounter + len;
  //FWriteThread.Write(b, len);
  byteWrote := 0;
  FillChar(Ovlap, SizeOf(TOverlapped), 0);
  Ovlap.hEvent := CreateEvent(nil, True, False, nil); //Create Event
  Succeed := WriteFile(FHndComm, b[0], Len, ignore, @Ovlap);
  //OK := WriteFile(FHndComm, Buf{b[0]}, Len, ignore, nil);
  //Repeat
  //  if WaitForSingleObject(Ovlap.hEvent, INFINITE) = WAIT_OBJECT_0 then begin
  //    OK := GetOverlappedResult(FHndComm, Ovlap, byteWrote, False);
  //    Inc(Ovlap.Offset, byteWrote);
  //  end;
  //  if Ovlap.Offset = Len then
  //    break;
  //  if OK or (GetLastError = ERROR_IO_PENDING) then begin
  //    OK := WriteFile(FHndComm, b[Ovlap.Offset], Len, byteWrote, @Ovlap);
  //    Inc(Ovlap.Offset, byteWrote);
  //  end;
  //until
  //  WriteQueue = 0;
  CloseHandle(Ovlap.hEvent);
  //Sleep(1);
  i := 10000;
  while i > 0 do begin
    Dec(i);
    sleep(0);
  end;
end;

procedure TCustomOSSerial.Write(const Buf; len: Integer);
begin
  WriteBuf(Buf, Len);
end;

{$endif}

procedure TCustomOSSerial.WriteString(S: String; EscapeChar: Char = #0);
begin
  if Length(s) = 0 then Exit;
  if EscapeChar <> #0 then begin
    if (Pos(EscapeChar +'n', s) + 1) <> (Pos(EscapeChar+EscapeChar, s)) then //new line
      s := ReplaceText(s, EscapeChar+'n', #10);
    if (Pos(EscapeChar+'r', s) + 1) <> (Pos(EscapeChar+EscapeChar, s)) then //return
      s := ReplaceText(s, EscapeChar+'r', #13);
    if (Pos(EscapeChar+'t', s) + 1) <> (Pos(EscapeChar+EscapeChar, s)) then //tab
      s := ReplaceText(s, EscapeChar+'t', #9);
  end;
  WriteBuf(s[1], Length(s));
end;

procedure TCustomOSSerial.WriteStr(S: String; EscapeChar: Char);
begin
  WriteString(S, EscapeChar);
end;

procedure TCustomOSSerial.WriteData(S: String);
begin
  WriteString(s);
end;

function TCustomOSSerial.WriteStrAsHex(S: String): String;
var b: TBytes;
    cs: TBytes;
begin
  Result := '';
  b := HexStrToBytes(S);
  if Assigned(CRC_Function) then begin
    cs := CRC_Function(b, Length(b));
    b := b + cs;
  end;
  WriteBuf(b[0], Length(b));
  Result := BytesToHexStr(b, Length(b), True);
end;

{$ifndef windows}
procedure TCustomOSSerial.ClearBuffer(RxBuffer , TxBuffer: Boolean);
begin
  if RxBuffer then begin
    RTLeventResetEvent(FSyncRead);
    SerFlushInput(FHndComm);
    FRxLength := 0;
  end;
  if TxBuffer then begin
    SerFlushOutput(FHndComm);
  end;
end;

{$else}
procedure TCustomOSSerial.ClearBuffer(RxBuffer , TxBuffer: Boolean);
begin
  if RxBuffer and TxBuffer then begin
    PurgeComm(FHndComm, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
    FRxLength := 0;
  end else begin
    if RxBuffer then begin
      //EscapeCommFunction(FHndComm, SETRTS);
      //EscapeCommFunction(FHndComm, CLRRTS);
      //
      //EscapeCommFunction(FHndComm, SETDTR);
      //EscapeCommFunction(FHndComm, CLRDTR);

      //EscapeCommFunction(FHndComm, CLRRTS);
      //EscapeCommFunction(FHndComm, CLRDTR);

      PurgeComm(FHndComm, PURGE_RXABORT or PURGE_RXCLEAR);
      FRxLength := 0;
    end;
    if TxBuffer then begin
      PurgeComm(FHndComm, PURGE_TXABORT or PURGE_TXCLEAR);
    end;
  end;
end;
{$endif}

{$ifndef windows}
function TCustomOSSerial.ReadQueue: Integer;
begin
  if FpIOCtl(FHndComm, TIOCINQ, @Result) <> 0 then
    Result := -1;
end;

{$else}
function TCustomOSSerial.ReadQueue: Integer;
var Err: DWORD;
    ComStat: TComStat;
begin
  Err := 0;
  if ClearCommError(FHndComm, Err, @ComStat) then
    Result := ComStat.cbInQue;
end;
{$endif}

{$ifndef windows}
function TCustomOSSerial.WriteQueue: Integer;
begin
  if FpIOCtl(FHndComm, TIOCOUTQ, @Result) <> 0 then
    Result := -1;
end;

{$else}
function TCustomOSSerial.WriteQueue: Integer;
var Err: DWORD;
    ComStat: TComStat;
begin
  Err := 0;
  if ClearCommError(FHndComm, Err, @ComStat) then
    Result := ComStat.cbOutQue;
end;
{$endif}

function TCustomOSSerial.Open: Boolean;
begin
  Enabled := True;
  Result := Enabled;
end;

function TCustomOSSerial.IsOpened: Boolean;
begin
  Result := Enabled;
end;

procedure TCustomOSSerial.Close;
begin
  Enabled := False;
end;

//function TCustomOSSerial.InputCount: Integer;
//begin
//  Result := ReadQueue;
//end;

function TCustomOSSerial.ChangeBaudRate(baud: dword): Boolean;
var br: dword;
    CanChange: Boolean;
begin
  Result := False;
  if FDCB.BaudRate = baud then Exit;
  if FEnabled then begin
    br := FDCB.BaudRate; //backup old baud
    CanChange := True;
    FDCB.BaudRate := baud;
{$IFDEF WINDOWS}
    if Assigned(OnCommStateChange) then
      OnCommStateChange(FDCB, CanChange);
    if CanChange then begin
      Result := SetCommState(FHndComm, FDCB);
    end;
{$endif}
    if not Result then
      FDCB.BaudRate := br;
  end;
end;

function TCustomOSSerial.UpdateComState(aDCB: TDCB): Boolean;
var CanChange: Boolean;
begin
  if FEnabled then begin
    CanChange := True;
{$IFDEF WINDOWS}
    if Assigned(OnCommStateChange) then
      OnCommStateChange(FDCB, CanChange);
    if CanChange then
      Result := SetCommState(FHndComm, aDCB);
{$ENDIF}
  end else
    raise Exception.Create('Port not open');
    //MessageDlg('Port not opened', mtError, [mbOk], 0);
end;

{$IFDEF WINDOWS}
function TCustomOSSerial.ChangeCOMSetting(Baudrate: dword; Databits: byte;
  Parity: TParity; Stopbits: TStopbits): Boolean;
var aDCB: TDCB;
    CanChange: Boolean;
begin
  if FEnabled then begin
    CanChange := True;
    if Assigned(OnCommStateChange) then
      OnCommStateChange(FDCB, CanChange);
    if CanChange then begin
      Result := GetCommState(FHndComm, aDCB);
      if Result then begin
        aDCB.BaudRate := Baudrate;
        aDCB.ByteSize := Databits;
        aDCB.Parity := Integer(Parity);
        aDCB.StopBits := Integer(Stopbits);
        Result := SetCommState(FHndComm, aDCB);
      end;
    end;
  end else
    raise Exception.Create('Port not open');
  //MessageDlg('Port not opened', mtError, [mbOk], 0);
end;

{$ELSE}
function TCustomOSSerial.ChangeCOMSetting(Baudrate: dword; Databits: byte;
  Parity: TParityType; Stopbits: TStopbits): Boolean;
var aDCB: TDCB;
    CanChange: Boolean;
begin
  if FEnabled then begin
    CanChange := True;
{$IFDEF WINDOWS}
    if Assigned(OnCommStateChange) then
      OnCommStateChange(FDCB, CanChange);
{$ENDIF}
    if CanChange then begin
      if Result then begin
        aDCB.BaudRate := Baudrate;
        aDCB.ByteSize := Databits;
        aDCB.Parity := Integer(Parity);
        aDCB.StopBits := Integer(Stopbits);
        SerSetParams(FHndComm, Baudrate, Databits, Parity, aDCB.Stopbits, []);
      end;
    end;
  end else
    raise Exception.Create('Port not open');
  //MessageDlg('Port not opened', mtError, [mbOk], 0);
end;

{$ENDIF}


procedure TCustomOSSerial.ResetCounters(Tx , Rx: Boolean);
begin
  if Tx then
    FTxCounter := 0;
  if Rx then
    FRxCounter := 0;
end;

{ TOSModbusRTUObject }

function TOSModbusRTUObject.GetCRC: String;
var b, _crc: TBytes;
begin
  Result := '';
  if Trim(FCommand) = '' then Exit;
  b := HexStrToBytes(FCommand);
  _crc := CRC16Swap_Modbus(b, Length(b));
  Result := BytesToHexStr(_crc, 2, true);
end;

procedure TOSModbusRTUObject.SetCommand(AValue: String);
begin
  if FCommand = AValue then Exit;
  FCommand := AValue;
  //FCRC := GetCRC;
end;

procedure TOSModbusRTUObject.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
end;

procedure TOSModbusRTUObject.SetFormat(AValue: String);
var s: String;
    v: Variant;
begin
  if FFormat = AValue then Exit;
  FFormat := AValue;
  //VarArrayCreate([0,1], varword);
  //VarArrayPut(v, $12, [0]);
  //VarArrayPut(v, $34, [1]);
  //Format(s, [v]);
//'%3*256+%4'
end;

procedure TOSModbusRTUObject.SetSerialCOM(AValue: TOSSerial);
begin
  if FOSSerial = AValue then Exit;
  if Assigned(AValue) then
    AValue.AddToNodeList(Self)
  else
    FOSSerial.DeleleFromNodeList(Self);
  FOSSerial := AValue;
end;

constructor TOSModbusRTUObject.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TOSModbusRTUObject.Destroy;
begin
  if Assigned(FOSSerial) then
    FOSSerial.DeleleFromNodeList(Self);
  inherited Destroy;
end;


Initialization
{$I OSSerial_icon.lrs}


end.

