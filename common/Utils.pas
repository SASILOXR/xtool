unit Utils;

{$POINTERMATH ON}

interface

uses
  Threading, SynCommons, lz4lib, ZSTDLib,
  WinAPI.Windows, WinAPI.PsAPI,
  System.SysUtils, System.Classes, System.SyncObjs, System.Math, System.Types,
  System.AnsiStrings, System.StrUtils, System.IniFiles, System.IOUtils,
  System.RTLConsts, System.TypInfo, System.ZLib, System.Net.HttpClientComponent,
  System.Net.HttpClient, System.Character, System.SysConst,
  System.Generics.Defaults, System.Generics.Collections;

procedure ShowMessage(Msg: string; Caption: string = '');
procedure WriteLine(S: String);
function GetModuleName: string;

type
  TInt8_BitCount = 1 .. 8;
  TInt8_BitIndex = 0 .. 7;
  TInt16_BitCount = 1 .. 16;
  TInt16_BitIndex = 0 .. 15;
  TInt32_BitCount = 1 .. 32;
  TInt32_BitIndex = 0 .. 31;
  TInt64_BitCount = 1 .. 64;
  TInt64_BitIndex = 0 .. 63;

function GetBits(Data: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount): Int64;
procedure SetBits(var Data: Int8; Value: Int8; Index: TInt8_BitIndex;
  Count: TInt8_BitCount); overload;
procedure SetBits(var Data: UInt8; Value: Int8; Index: TInt8_BitIndex;
  Count: TInt8_BitCount); overload;
procedure SetBits(var Data: Int16; Value: Int16; Index: TInt16_BitIndex;
  Count: TInt16_BitCount); overload;
procedure SetBits(var Data: UInt16; Value: Int16; Index: TInt16_BitIndex;
  Count: TInt16_BitCount); overload;
procedure SetBits(var Data: Int32; Value: Int32; Index: TInt32_BitIndex;
  Count: TInt32_BitCount); overload;
procedure SetBits(var Data: UInt32; Value: Int32; Index: TInt32_BitIndex;
  Count: TInt32_BitCount); overload;
procedure SetBits(var Data: Int64; Value: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount); overload;
procedure SetBits(var Data: UInt64; Value: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount); overload;

type
  TListEx<T> = class(TList<T>)
  private
    FIndex: Integer;
  public
    constructor Create(const AComparer: IComparer<T>); overload;
    procedure Delete(Index: Integer);
    function Get(var Value: T): Integer; overload;
    function Get(var Value: T; Index: Integer): Boolean; overload;
    property Index: Integer read FIndex write FIndex;
  end;

  TSOMethod = (MTF, Transpose, Count);

  TSOList = class(TObject)
  private type
    TSOInfo = record
      Value, Count: Integer;
    end;

    TSOInfoComparer = class(TComparer<TSOInfo>)
    public
      function Compare(const Left, Right: TSOInfo): Integer; override;
    end;
  private
    FComparer: TSOInfoComparer;
    FList: TList<TSOInfo>;
    FSOMethod: TSOMethod;
    FIndex: Integer;
    function GetCount: Integer;
  public
    constructor Create(AValues: TArray<Integer>;
      ASOMethod: TSOMethod = TSOMethod.MTF);
    destructor Destroy; override;
    procedure Update(AValues: TArray<Integer>; Add: Boolean = False);
    procedure Add(Value: Integer);
    function Get(var Value: Integer): Integer;
    property Index: Integer read FIndex write FIndex;
    property Count: Integer read GetCount;
    property Method: TSOMethod read FSOMethod write FSOMethod;
  end;

  TNullStream = class(TStream)
  private
    FPosition, FSize: Int64;
  public
    constructor Create;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  TArrayStream = class(TStream)
  private type
    _Stream = ^IStream;

    IStream = record
      Instance: TStream;
      Position, Size, MaxSize: Int64;
    end;
  private const
    FMaxStreamSize = $FFFFFFFFFF;
  protected
    function GetSize: Int64; override;
    procedure SetSize(NewSize: LongInt); override;
    procedure SetSize(const NewSize: Int64); override;
  private
    FStreams: TArray<IStream>;
    FPosition, FSize: Int64;
    FIndex, FCount: Integer;
    procedure FSetPos(APosition: Int64);
    procedure FSetSize(ASize: Int64);
    procedure FUpdateRead;
    procedure FUpdateWrite;
  public
    constructor Create;
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure Clear;
    function Add(AStreamType: Pointer; MaxSize: Int64 = FMaxStreamSize)
      : Integer overload;
    function Add(AStream: TStream; MaxSize: Int64 = FMaxStreamSize)
      : Integer overload;
    procedure Update(Index: Integer; MaxSize: Int64);
    function MaxSize(Index: Integer): Int64;
    property Count: Integer read FCount;
  end;

  TMemoryStreamEx = class(TMemoryStream)
  private const
    FIncSize = $2000000;
  private
    FOwnMemory: Boolean;
    FMemory: Pointer;
    FMaxSize: NativeInt;
    FSize, FPosition: NativeInt;
    FCanAccess: Boolean;
    FAccessCount: Integer;
  public
    constructor Create(AOwnMemory: Boolean = True; const AMemory: Pointer = nil;
      AMaxSize: NativeInt = 0); overload;
    destructor Destroy; override;
    procedure SetSize(const NewSize: Int64); override;
    procedure SetSize(NewSize: LongInt); override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure Update(const AMemory: Pointer = nil; AMaxSize: NativeInt = 0);
    function Enter: Boolean;
    procedure Leave;
  end;

  TMemoryStreamEx2 = class(TMemoryStream)
  protected
    function Realloc(var NewCapacity: NativeInt): Pointer; override;
  end;

  TFileStreamEx = class(TStream)
  private
    FFileName: String;
    FViewSize: Integer;
    FStream: TFileStream;
    FPosition, FSize, FMaxSize: Int64;
    FMapPos, FMapSize: Int64;
    FSysInfo: TSystemInfo;
    FMapHandle: THandle;
    FMapBuffer: Pointer;
    function CalcPos(APos: Int64): Int64;
    function CalcSize(ASize: Int64): Int64;
    procedure IncSize(ANewSize: Int64);
    function DoMap(APosition: Int64): Boolean;
  public
    constructor Create(const AFileName: String; AViewSize: Integer = $400000);
    destructor Destroy; override;
    procedure SetSize(const NewSize: Int64); override;
    procedure SetSize(NewSize: LongInt); override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function Map(APosition: Int64; ASize: NativeInt): Pointer;
    function CopyTo(Dest: TStream; Count: Int64 = 0): Int64;
    procedure Update;
    procedure Fill(Value: Byte; Count: Int64);
    property FileName: String read FFileName;
  end;

  TDirInputStream = class(TStream)
  protected type
    TState = (iNone, iLength, iFilename, iSize, iData);
  private
    FState: TState;
    FPath: String;
    FBaseDir: String;
    FList: TArray<String>;
    FIndex, FCount: Integer;
    FLength: Word;
    FBytes: TBytes;
    FStream: TFileStream;
    FPosition, FSize: Int64;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
  end;

  TDirOutputStream = class(TStream)
  protected type
    TState = (oNone, oLength, oFilename, oSize, oData);
  private
    FState: TState;
    FPath: String;
    FLength: Word;
    FBytes: TBytes;
    FStream: TFileStreamEx;
    FPosition, FSize: Int64;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
  end;

  TDownloadStream = class(TStream)
  private const
    FChunkSize = 1048576;
  private
    FUrl: string;
    FNetHTTPClient: TNetHTTPClient;
    FMemoryStream: TMemoryStream;
    FSize, FPosition: Int64;
    procedure NetHTTPClientReceiveData(const Sender: TObject;
      AContentLength, AReadCount: Int64; var Abort: Boolean);
  public
    constructor Create(Url: string);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  TBufferedStream = class(TStream)
  protected
    function GetSize: Int64; override;
  private
    FSize: Int64;
    FReadMode: Boolean;
    FMemory: PByte;
    FBufferSize: Integer;
    FBufPos, FBufSize: Integer;
  public
    Instance: TStream;
    constructor Create(Stream: TStream; ReadMode: Boolean;
      BufferSize: Integer = 65536);
    destructor Destroy; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Write(const Buffer; Count: Integer): Integer; override;
    procedure Flush;
  end;

  TProcessStream = class(TStream)
  private
    FInput, FOutput, FError: TStream;
    FTask, FTask2: TTask;
    FProcessInfo: TProcessInformation;
    FStdinr, FStdinw: THandle;
    FStdoutr, FStdoutw: THandle;
    FStderrr, FStderrw: THandle;
    FExecutable, FCommandLine, FWorkDir: String;
    FInSize, FOutSize: Int64;
    procedure ExecReadTask;
    procedure ExecWriteTask;
    procedure ExecErrorTask;
  public
    constructor Create(AExecutable, ACommandLine, AWorkDir: String;
      AInput: TStream = nil; AOutput: TStream = nil; AError: TStream = nil);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Execute: Boolean;
    procedure Wait;
    function Done: Boolean;
    function Running: Boolean;
    property InSize: Int64 read FInSize;
    property OutSize: Int64 read FOutSize;
  end;

  TStoreStream = class(TMemoryStreamEx)
  private
    FOnFull: TStreamProc;
  public
    constructor Create(ASize: NativeInt); overload;
    destructor Destroy; override;
    function Write(const Buffer; Count: Integer): Integer; override;
    procedure Flush;
    property OnFull: TStreamProc read FOnFull write FOnFull;
  end;

  TCacheCompression = (ccNone, ccLZ4, ccZSTD);

  TCacheReadStream = class(TStream)
  protected
    function FCallback(ASize: Int64): Boolean;
    procedure FOnFull(Stream: TStream);
  private const
    FBufferSize = $400000;
  private
    FSync: TSynLocker;
    FInput, FCache: TStream;
    FStorage1: TStoreStream;
    FStorage2: TMemoryStreamEx;
    FCompBuffer: Pointer;
    FCompBufferSize: Integer;
    FTask: TTask;
    FPosition1, FPosition2: Int64;
    FUsedSize, FMaxSize: Int64;
    FDone: Boolean;
    FComp: TCacheCompression;
    FCCtx: ZSTD_CCtx;
    FDCtx: ZSTD_DCtx;
    FCached: Int64;
    procedure CacheMemory;
  public
    constructor Create(Input, Cache: TStream;
      AComp: TCacheCompression = ccNone);
    destructor Destroy; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Cached(Compressed: PInt64): Int64;
  end;

  TCacheWriteStream = class(TStream)
  protected
    procedure FOnFull(Stream: TStream);
  private const
    FBufferSize = $400000;
  private
    FSync: TSynLocker;
    FOutput, FCache: TStream;
    FBuffer: Pointer;
    FStorage: TStoreStream;
    FCompBuffer: Pointer;
    FCompBufferSize: Integer;
    FTask: TTask;
    FPosition1, FPosition2: Int64;
    FUsedSize, FMaxSize: Int64;
    FDone: Boolean;
    FComp: TCacheCompression;
    FCCtx: ZSTD_CCtx;
    FDCtx: ZSTD_DCtx;
    FCached: Int64;
    procedure CacheMemory;
  public
    constructor Create(Output, Cache: TStream;
      AComp: TCacheCompression = ccNone);
    destructor Destroy; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Cached(Compressed: PInt64): Int64;
  end;

  TDataStore = class(TObject)
  public
    function Slot(Index: Integer): TMemoryStream; virtual; abstract;
    function Position(Index: Integer): Int64; virtual; abstract;
    function Size(Index: Integer): NativeInt; virtual; abstract;
    function ActualSize(Index: Integer): NativeInt; virtual; abstract;
    function Slots: NativeInt; virtual; abstract;
    function Done: Boolean; virtual; abstract;
  end;

  TDataStore1 = class(TDataStore)
  private const
    FBufferSize = 65536;
  private
    FSync: TSynLocker;
    FInput: TStream;
    FTemp: TFileStreamEx;
    FTempFile: String;
    FTempPos: Int64;
    FBuffer: array [0 .. FBufferSize - 1] of Byte;
    FDynamic: Boolean;
    FIndex: Integer;
    FSlots, FSize: NativeInt;
    FMemPtr: Pointer;
    FMemStm: TMemoryStreamEx;
    FMemData: TArray<TMemoryStreamEx>;
    FPositions: TArray<Int64>;
    FDone, FFirstRead, FLastRead: Boolean;
  public
    constructor Create(AInput: TStream; ADynamic: Boolean;
      ASlots, ASize: NativeInt; ATempFile: String = 'datastore.tmp');
    destructor Destroy; override;
    procedure ChangeInput(AInput: TStream);
    function Read(Index: Integer; Position: NativeInt; var Buffer;
      Count: Integer): Integer;
    function Slot(Index: Integer): TMemoryStream; override;
    function Position(Index: Integer): Int64; override;
    function Size(Index: Integer): NativeInt; override;
    function ActualSize(Index: Integer): NativeInt; override;
    function Slots: NativeInt; override;
    function Done: Boolean; override;
    procedure Load;
    procedure LoadEx;
  end;

  TDataStore2 = class(TDataStore)
  private
    FSlots: NativeInt;
    FMemData: TArray<TMemoryStream>;
    FPositions, FSizes: TArray<Int64>;
  public
    constructor Create(ASlots: NativeInt);
    destructor Destroy; override;
    function Slot(Index: Integer): TMemoryStream; override;
    function Position(Index: Integer): Int64; override;
    function Size(Index: Integer): NativeInt; override;
    function ActualSize(Index: Integer): NativeInt; override;
    function Slots: NativeInt; override;
    function Done: Boolean; override;
    procedure Load(Index: Integer; Memory: Pointer; Size: Integer);
    procedure Reset(Index: Integer);
  end;

  TDataManager = class(TObject)
  private type
    PBlockInfo = ^TBlockInfo;

    TBlockInfo = record
      ID: Integer;
      Position: Int64;
      CurrSize, FullSize: Integer;
      Count: Integer;
    end;
  private
    FSearchList: TArray<TBlockInfo>;
    FStream: TStream;
    FStreamPos, FStreamSize: Int64;
  public
    constructor Create(AStream: TStream);
    destructor Destroy; override;
    procedure Add(ID: Integer; Size: Integer;
      Count: Integer = Integer.MaxValue);
    procedure Write(ID: Integer; Buffer: Pointer; Size: Integer);
    procedure CopyData(ID: Integer; Stream: TStream); overload;
    function CopyData(ID: Integer; Data: Pointer): Integer; overload;
    procedure Update(ID: Integer; Count: Integer);
    procedure Reset(ID: Integer);
  end;

  TArgParser = class(TObject)
  private
    FArgs: TStringDynArray;
  public
    constructor Create(Arguments: TStringDynArray);
    destructor Destroy; override;
    procedure Add(Arguments: String);
    function AsString(Parameter: String; Index: Integer = 0;
      Default: String = ''): String;
    function AsInteger(Parameter: String; Index: Integer = 0;
      Default: Integer = 0): Integer;
    function AsFloat(Parameter: String; Index: Integer = 0;
      Default: Single = 0.00): Single;
    function AsBoolean(Parameter: String; Index: Integer = 0;
      Default: Boolean = False): Boolean;
  end;

  TDynamicEntropy = class(TObject)
  private
    FFirstBytes: TBytes;
    FFirstBytesPos: Integer;
    FEntropy: Single;
    FIndex, FRange: Integer;
    F1: array [0 .. 255] of Integer;
    F2: array of Byte;
    F3: array of Single;
  public
    constructor Create(ARange: Integer);
    destructor Destroy; override;
    procedure Reset;
    function Value: Single;
    procedure AddByte(AByte: Byte);
    procedure AddData(AData: Pointer; Size: Integer);
    property Range: Integer read FRange;
  end;

  PExecOutput = ^TExecOutput;
  TExecOutput = reference to procedure(const Buffer: Pointer; Size: Integer);

function CRC32(CRC: longword; buf: PByte; len: cardinal): longword;
function Hash32(CRC: longword; buf: PByte; len: cardinal): longword;

procedure XORBuffer(InBuff: PByte; InSize: Integer; KeyBuff: PByte;
  KeySize: Integer);

function GenerateGUID: string;

function CalculateEntropy(Buffer: Pointer; BufferSize: Integer): Single;

function CopyStream(AStream1, AStream2: TStream; ASize: Int64 = Int64.MaxValue;
  ACallback: TFunc<Int64, Boolean> = nil): Int64;
procedure CopyStreamEx(AStream1, AStream2: TStream; ASize: Int64;
  ACallback: TFunc<Int64, Boolean> = nil);

function EndianSwap(A: Single): Single; overload;
function EndianSwap(A: double): double; overload;
function EndianSwap(A: Int64): Int64; overload;
function EndianSwap(A: UInt64): UInt64; overload;
function EndianSwap(A: Int32): Int32; overload;
function EndianSwap(A: UInt32): UInt32; overload;
function EndianSwap(A: Int16): Int16; overload;
function EndianSwap(A: UInt16): UInt16; overload;

function BinarySearch(SrcMem: Pointer; SrcPos, SrcSize: NativeInt;
  SearchMem: Pointer; SearchSize: NativeInt; var ResultPos: NativeInt): Boolean;
function BinarySearch2(SrcMem: Pointer; SrcPos, SrcSize: NativeInt;
  SearchMem: Pointer; SearchSize: NativeInt; var ResultPos: NativeInt): Boolean;
procedure ReverseBytes(Source, Dest: Pointer; Size: NativeInt);

function EncodePatch(OldBuff: Pointer; OldSize: Integer; NewBuff: Pointer;
  NewSize: Integer; PatchBuff: Pointer; PatchSize: Integer): Integer;
function DecodePatch(PatchBuff: Pointer; PatchSize: Integer; OldBuff: Pointer;
  OldSize: Integer; NewBuff: Pointer; NewSize: Integer): Integer;
function CloseValues(Value, Min, Max: Integer): TArray<Integer>;

function CompareSize(Original, New, Current: Int64): Boolean;

function GetIniString(Section, Key, Default, FileName: string): string;
  overload;
function GetIniString(Section, Key, Default: string; Ini: TMemIniFile)
  : string; overload;
procedure SetIniString(Section, Key, Value, FileName: string); overload;
procedure SetIniString(Section, Key, Value: string; Ini: TMemIniFile); overload;
function DecodeStr(str, Dec: string; Count: Integer = Integer.MaxValue - 1)
  : TStringDynArray;
function AnsiDecodeStr(str, Dec: Ansistring): TArray<Ansistring>;
function GetStr(Input: Pointer; MaxLength: Integer; var outStr: string)
  : Integer;
function IndexTextA(AText: PAnsiChar;
  const AValues: array of PAnsiChar): Integer;
function IndexTextW(AText: PWideChar;
  const AValues: array of PWideChar): Integer;
function CaseStr(AIndex: Integer; const AValues: array of String): String;
function CaseInt(AIndex: Integer; const AValues: array of Integer): Integer;

procedure Relocate(AMemory: PByte; ASize: NativeInt; AFrom, ATo: NativeInt);
  deprecated;

function ConvertToBytes(S: string): Int64;
function ConvertToThreads(S: string): Integer;
function ConvertKB2TB(Value: Int64): string;

function BoolArray(const Bool: TArray<Boolean>; Value: Boolean): Boolean;

function GetUsedProcessMemory(hProcess: THandle): Int64;
function GetFreeSystemMemory: Int64;
function GetUsedSystemMemory: Int64;
function GetTotalSystemMemory: Int64;

function FileSize(const AFileName: string): Int64;
function GetFileList(const APath: TArray<string>; SubDir: Boolean = True)
  : TArray<string>;
procedure FileReadBuffer(Handle: THandle; var Buffer; Count: NativeInt);
procedure FileWriteBuffer(Handle: THandle; const Buffer; Count: NativeInt);
procedure CloseHandleEx(var Handle: THandle);
function ExpandPath(const AFileName: string;
  AFullPath: Boolean = False): String;

function Exec(Executable, CommandLine, WorkDir: string): Boolean;
function ExecStdin(Executable, CommandLine, WorkDir: string; InBuff: Pointer;
  InSize: Integer): Boolean overload;
function ExecStdin(Executable, CommandLine, WorkDir: string; InStream: TStream)
  : Boolean overload;
function ExecStdout(Executable, CommandLine, WorkDir: string;
  Output: TExecOutput): Boolean;
function ExecStdio(Executable, CommandLine, WorkDir: string; InBuff: Pointer;
  InSize: Integer; Output: TExecOutput): Boolean overload;
function ExecStdio(Executable, CommandLine, WorkDir: string; InStream: TStream;
  Output: TExecOutput): Boolean overload;
function GetCmdStr(CommandLine: String; Index: Integer;
  KeepQuotes: Boolean = False): string;
function GetCmdCount(CommandLine: String): Integer;

implementation

function GetBits(Data: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount): Int64;
begin
  Result := (Data shr Index) and ((1 shl Count) - 1);
end;

procedure SetBits(var Data: Int8; Value: Int8; Index: TInt8_BitIndex;
  Count: TInt8_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: UInt8; Value: Int8; Index: TInt8_BitIndex;
  Count: TInt8_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: Int16; Value: Int16; Index: TInt16_BitIndex;
  Count: TInt16_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: UInt16; Value: Int16; Index: TInt16_BitIndex;
  Count: TInt16_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: Int32; Value: Int32; Index: TInt32_BitIndex;
  Count: TInt32_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: UInt32; Value: Int32; Index: TInt32_BitIndex;
  Count: TInt32_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: Int64; Value: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure SetBits(var Data: UInt64; Value: Int64; Index: TInt64_BitIndex;
  Count: TInt64_BitCount);
var
  I: Integer;
begin
  I := Index + Count;
  Data := (GetBits(Data, I, Data.Size * 8 - I) shl I) or
    (GetBits(Value, 0, Count) shl Index) or GetBits(Data, 0, Index);
end;

procedure ShowMessage(Msg: string; Caption: string = '');
begin
  MessageBox(0, PChar(Msg), PChar(Caption), MB_OK or MB_TASKMODAL);
end;

procedure WriteLine(S: String);
var
  ulLength: cardinal;
begin
  WriteConsole(GetStdHandle(STD_ERROR_HANDLE), PChar(S + #13#10),
    Length(S + #13#10), ulLength, nil);
end;

function GetModuleName: string;
var
  szFileName: array [0 .. MAX_PATH] of char;
begin
  FillChar(szFileName, sizeof(szFileName), #0);
  GetModuleFileName(hInstance, szFileName, MAX_PATH);
  Result := szFileName;
end;

constructor TListEx<T>.Create(const AComparer: IComparer<T>);
begin
  inherited Create(AComparer);
end;

procedure TListEx<T>.Delete(Index: Integer);
begin
  inherited Delete(Index);
  if (Index < FIndex) then
    Dec(FIndex);
end;

function TListEx<T>.Get(var Value: T): Integer;
begin
  Result := -1;
  if (InRange(FIndex, 0, Pred(Count)) = False) or (Count <= 0) then
    exit;
  Value := Self[FIndex];
  Result := FIndex;
  Inc(FIndex);
end;

function TListEx<T>.Get(var Value: T; Index: Integer): Boolean;
begin
  Result := False;
  if (InRange(Index, 0, Pred(Count)) = False) or (Count <= 0) then
    exit;
  Value := Self[Index];
  Result := True;
end;

constructor TSOList.Create(AValues: TArray<Integer>; ASOMethod: TSOMethod);
var
  I: Integer;
  FInfo: TSOInfo;
begin
  inherited Create;
  FComparer := TSOInfoComparer.Create;
  FList := TList<TSOInfo>.Create(FComparer);
  FList.Count := Length(AValues);
  for I := 0 to FList.Count - 1 do
  begin
    FInfo.Value := AValues[Low(AValues) + I];
    FInfo.Count := 0;
    FList[I] := FInfo;
  end;
  FSOMethod := ASOMethod;
  FIndex := 0;
end;

destructor TSOList.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TSOList.TSOInfoComparer.Compare(const Left, Right: TSOInfo): Integer;
begin
  Result := Right.Count - Left.Count;
end;

procedure TSOList.Update(AValues: TArray<Integer>; Add: Boolean);
var
  I: Integer;
  FInfo: TSOInfo;
begin
  if not Add then
    FList.Count := Length(AValues);
  for I := Low(AValues) to High(AValues) do
  begin
    FInfo.Value := AValues[I];
    FInfo.Count := 0;
    if Add then
      FList.Add(FInfo)
    else
      FList[I] := FInfo;
  end;
  FIndex := 0;
end;

function TSOList.Get(var Value: Integer): Integer;
begin
  Result := -1;
  if (InRange(FIndex, 0, Pred(Count)) = False) or (Count <= 0) then
    exit;
  try
    Value := FList[FIndex].Value;
    Result := FIndex;
    Inc(FIndex);
  except
  end;
end;

procedure TSOList.Add(Value: Integer);
var
  I: Integer;
  FInfo: TSOInfo;
begin
  case FSOMethod of
    TSOMethod.MTF:
      for I := 0 to FList.Count - 1 do
        if FList[I].Value = Value then
        begin
          FList.Move(I, 0);
          break;
        end;
    TSOMethod.Transpose:
      for I := 1 to FList.Count - 1 do
        if FList[I].Value = Value then
        begin
          FList.Move(I, I - 1);
          break;
        end;
    TSOMethod.Count:
      for I := 0 to FList.Count - 1 do
        if FList[I].Value = Value then
        begin
          FInfo := FList[I];
          Inc(FInfo.Count);
          FList[I] := FInfo;
          FList.Sort;
          break;
        end;
  end;
end;

function TSOList.GetCount: Integer;
begin
  Result := FList.Count;
end;

constructor TNullStream.Create;
begin
  inherited Create;
  FPosition := 0;
  FSize := 0;
end;

function TNullStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Inc(FPosition, Count);
  Result := Count;
end;

function TNullStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  Inc(FPosition, Count);
  if FSize < FPosition then
    FSize := FPosition;
  Result := Count;
end;

function TNullStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := Position;
end;

constructor TArrayStream.Create;
begin
  inherited Create;
  Clear;
end;

destructor TArrayStream.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FStreams[I].Instance.Free;
  Clear;
  inherited Destroy;
end;

procedure TArrayStream.FSetPos(APosition: Int64);
var
  I: Integer;
  LPosition, LSize: Int64;
  B: Boolean;
begin
  FIndex := 0;
  LPosition := 0;
  LSize := 0;
  B := False;
  for I := 0 to FCount - 1 do
  begin
    FStreams[I].Position := Min(FStreams[I].Size, Max(0, APosition - LSize));
    FStreams[I].Instance.Position := FStreams[I].Position;
    if (B = False) and (APosition <= LSize + FStreams[I].Size) then
    begin
      FIndex := I;
      B := True;
    end;
    Inc(LPosition, FStreams[I].Position);
    Inc(LSize, FStreams[I].Size);
  end;
  FPosition := LPosition;
end;

procedure TArrayStream.FSetSize(ASize: Int64);
var
  I: Integer;
  LSize: Int64;
begin
  LSize := 0;
  for I := 0 to FCount - 1 do
  begin
    FStreams[I].Size := Min(FStreams[I].MaxSize, Max(0, ASize - LSize));
    FStreams[I].Instance.Size := FStreams[I].Size;
    Inc(LSize, FStreams[I].Size);
  end;
  FSize := LSize;
end;

procedure TArrayStream.FUpdateRead;
begin
  if FStreams[FIndex].Position = FStreams[FIndex].Size then
  begin
    while Succ(FIndex) < FCount do
    begin
      Inc(FIndex);
      FStreams[FIndex].Instance.Position := 0;
      FStreams[FIndex].Position := 0;
      if FStreams[FIndex].Position < FStreams[FIndex].Size then
        break;
    end;
  end;
end;

procedure TArrayStream.FUpdateWrite;
begin
  if FStreams[FIndex].Position = FStreams[FIndex].MaxSize then
  begin
    while Succ(FIndex) < FCount do
    begin
      Inc(FIndex);
      FStreams[FIndex].Instance.Position := 0;
      FStreams[FIndex].Position := 0;
      if FStreams[FIndex].Position < FStreams[FIndex].MaxSize then
        break;
    end;
  end;
end;

function TArrayStream.GetSize: Int64;
begin
  Result := FSize;
end;

procedure TArrayStream.SetSize(NewSize: LongInt);
begin
  SetSize(Int64(NewSize));
end;

procedure TArrayStream.SetSize(const NewSize: Int64);
begin
  FSetSize(NewSize);
  FSize := NewSize;
  if FPosition > NewSize then
    Seek(0, soEnd);
end;

function TArrayStream.Read(var Buffer; Count: LongInt): LongInt;
var
  LCount: Int64;
begin
  Result := 0;
  if FCount = 0 then
    exit;
  FUpdateRead;
  LCount := Min(FStreams[FIndex].Size - FStreams[FIndex].Position,
    Int64(Count));
  Result := FStreams[FIndex].Instance.Read(Buffer, LCount);
  Inc(FStreams[FIndex].Position, Result);
  Inc(FPosition, Result);
end;

function TArrayStream.Write(const Buffer; Count: LongInt): LongInt;
var
  LCount: Int64;
begin
  Result := 0;
  if FCount = 0 then
    exit;
  FUpdateWrite;
  LCount := Min(FStreams[FIndex].MaxSize - FStreams[FIndex].Position,
    Int64(Count));
  Result := FStreams[FIndex].Instance.Write(Buffer, LCount);
  Inc(FStreams[FIndex].Position, Result);
  FStreams[FIndex].Size := Max(FStreams[FIndex].Position,
    FStreams[FIndex].Size);
  Inc(FPosition, Result);
  FSize := Max(FPosition, FSize);
end;

function TArrayStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  FSetPos(FPosition);
  Result := FPosition;
end;

procedure TArrayStream.Clear;
begin
  SetLength(FStreams, 0);
  FPosition := 0;
  FSize := 0;
  FIndex := 0;
  FCount := 0;
end;

function TArrayStream.Add(AStreamType: Pointer; MaxSize: Int64): Integer;
var
  LTypeData: PTypeData;
begin
  Result := FCount;
  Inc(FCount);
  SetLength(FStreams, FCount);
  LTypeData := GetTypeData(AStreamType);
  FStreams[Pred(FCount)].Instance := TStream(LTypeData^.ClassType.Create);
  FStreams[Pred(FCount)].Instance.Position := 0;
  FStreams[Pred(FCount)].Instance.Size := 0;
  FStreams[Pred(FCount)].Position := 0;
  FStreams[Pred(FCount)].Size := 0;
  FStreams[Pred(FCount)].MaxSize := EnsureRange(MaxSize, 0, FMaxStreamSize);
end;

function TArrayStream.Add(AStream: TStream; MaxSize: Int64): Integer;
begin
  Result := FCount;
  Inc(FCount);
  SetLength(FStreams, FCount);
  FStreams[Pred(FCount)].Instance := AStream;
  FStreams[Pred(FCount)].Instance.Position := 0;
  FStreams[Pred(FCount)].Instance.Size := 0;
  FStreams[Pred(FCount)].Position := 0;
  FStreams[Pred(FCount)].Size := 0;
  FStreams[Pred(FCount)].MaxSize := EnsureRange(MaxSize, 0, FMaxStreamSize);
end;

procedure TArrayStream.Update(Index: Integer; MaxSize: Int64);
begin
  if FStreams[Index].Size < MaxSize then
    FStreams[Index].MaxSize := MaxSize;
end;

function TArrayStream.MaxSize(Index: Integer): Int64;
begin
  Result := FStreams[Index].MaxSize;
end;

constructor TMemoryStreamEx.Create(AOwnMemory: Boolean; const AMemory: Pointer;
  AMaxSize: NativeInt);
begin
  inherited Create;
  FOwnMemory := AOwnMemory;
  FMemory := AMemory;
  SetPointer(FMemory, 0);
  FMaxSize := AMaxSize;
  FPosition := 0;
  FSize := 0;
  FCanAccess := True;
  FAccessCount := 0;
end;

destructor TMemoryStreamEx.Destroy;
begin
  SetPointer(nil, 0);
  if FOwnMemory then
    FreeMemory(FMemory);
  inherited Destroy;
end;

procedure TMemoryStreamEx.SetSize(NewSize: LongInt);
begin
  SetSize(Int64(NewSize));
end;

procedure TMemoryStreamEx.SetSize(const NewSize: Int64);
var
  OldPosition: NativeInt;
begin
  OldPosition := FPosition;
  if NewSize <= FMaxSize then
    FSize := NewSize;
  if OldPosition > NewSize then
    Seek(0, soEnd);
end;

function TMemoryStreamEx.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result := 0;
  if (FPosition >= 0) and (Count >= 0) then
  begin
    if FSize - FPosition > 0 then
    begin
      if FSize > Count + FPosition then
        Result := Count
      else
        Result := FSize - FPosition;
      Move((PByte(Memory) + FPosition)^, Buffer, Result);
      Inc(FPosition, Result);
    end;
  end;
end;

function TMemoryStreamEx.Write(const Buffer; Count: LongInt): LongInt;
var
  LCount: LongInt;
  LSize: NativeInt;
  LAccessCount: Integer;
begin
  Result := 0;
  LCount := Count;
  if FOwnMemory and (FPosition + LCount > FMaxSize) then
  begin
    FCanAccess := False;
    Sleep(10);
    AtomicExchange(LAccessCount, FAccessCount);
    while LAccessCount > 0 do
    begin
      Sleep(1);
      AtomicExchange(LAccessCount, FAccessCount);
    end;
    LSize := IfThen((FPosition + LCount) mod FIncSize = 0,
      FIncSize * ((FPosition + LCount) div FIncSize),
      FIncSize + FIncSize * ((FPosition + LCount) div FIncSize));
    if FMaxSize = 0 then
    begin
      FMemory := GetMemory(LSize);
      FMaxSize := LSize;
    end
    else
    begin
      FMemory := ReallocMemory(FMemory, LSize);
      FMaxSize := LSize;
    end;
    SetPointer(FMemory, FMaxSize);
    FCanAccess := True;
  end;
  if FPosition + LCount > FMaxSize then
    LCount := FMaxSize - FPosition;
  if (FPosition >= 0) and (LCount >= 0) then
  begin
    System.Move(Buffer, (PByte(Memory) + FPosition)^, LCount);
    Inc(FPosition, LCount);
    if FPosition > FSize then
      FSize := FPosition;
    Result := LCount;
  end;
end;

function TMemoryStreamEx.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := Min(FPosition, FMaxSize);
end;

procedure TMemoryStreamEx.Update(const AMemory: Pointer; AMaxSize: NativeInt);
var
  LSize: NativeInt;
begin
  if FOwnMemory then
    FreeMemory(FMemory);
  LSize := Min(FSize, AMaxSize);
  FMemory := AMemory;
  SetPointer(AMemory, LSize);
  FMaxSize := AMaxSize;
  SetSize(LSize);
end;

function TMemoryStreamEx.Enter: Boolean;
begin
  Result := FCanAccess;
  if Result then
    AtomicIncrement(FAccessCount);
end;

procedure TMemoryStreamEx.Leave;
begin
  AtomicDecrement(FAccessCount);
end;

function TMemoryStreamEx2.Realloc(var NewCapacity: NativeInt): Pointer;
const
  MemoryDelta = $2000;
begin
  if (NewCapacity > 0) and (NewCapacity <> Self.Size) then
    NewCapacity := (NewCapacity + (MemoryDelta - 1)) and not(MemoryDelta - 1);
  Result := Memory;
  if NewCapacity <> Self.Size then
  begin
    if NewCapacity = 0 then
    begin
      FreeMemory(Memory);
      Result := nil;
    end
    else
    begin
      if Capacity = 0 then
        Result := GetMemory(NewCapacity)
      else
        Result := ReallocMemory(Result, NewCapacity);
      if Result = nil then
        raise EStreamError.CreateRes(@SMemoryStreamError);
    end;
  end;
end;

constructor TFileStreamEx.Create(const AFileName: string; AViewSize: Integer);
  function FSMode(OpenAndUse: Boolean): Word;
  begin
    if OpenAndUse then
      Result := fmOpenReadWrite or fmShareDenyNone
    else
      Result := fmCreate or fmShareDenyNone;
  end;

var
  I64: Int64;
begin
  inherited Create;
  FFileName := AFileName;
  if AViewSize <= 0 then
    raise ERangeError.CreateRes(@SRangeError);
  FViewSize := AViewSize;
  FStream := TFileStream.Create(AFileName, FSMode(FileExists(AFileName)));
  FPosition := 0;
  FSize := FileSize(FStream.FileName);
  FMaxSize := FSize;
  GetSystemInfo(FSysInfo);
  FMapHandle := 0;
  if FMaxSize > 0 then
    FMapHandle := CreateFileMapping(FStream.Handle, nil, PAGE_READWRITE,
      Int64Rec(FMaxSize).Hi, Int64Rec(FMaxSize).Lo, '');
end;

destructor TFileStreamEx.Destroy;
begin
  if Assigned(FMapBuffer) then
  begin
    UnmapViewOfFile(FMapBuffer);
    FMapBuffer := nil;
  end;
  CloseHandleEx(FMapHandle);
  FStream.Size := FSize;
  FStream.Free;
  inherited Destroy;
end;

function TFileStreamEx.CalcPos(APos: Int64): Int64;
begin
  Result := FSysInfo.dwAllocationGranularity *
    (APos div FSysInfo.dwAllocationGranularity);
end;

function TFileStreamEx.CalcSize(ASize: Int64): Int64;
begin
  Result := IfThen(ASize mod FViewSize = 0, FViewSize * (ASize div FViewSize),
    FViewSize + FViewSize * (ASize div FViewSize));
end;

procedure TFileStreamEx.IncSize(ANewSize: Int64);
var
  LSize: Int64;
begin
  if Assigned(FMapBuffer) then
  begin
    UnmapViewOfFile(FMapBuffer);
    FMapBuffer := nil;
  end;
  CloseHandleEx(FMapHandle);
  FMaxSize := CalcSize(ANewSize);
  FStream.Size := FMaxSize;
  if FMaxSize > 0 then
    FMapHandle := CreateFileMapping(FStream.Handle, nil, PAGE_READWRITE,
      Int64Rec(FMaxSize).Hi, Int64Rec(FMaxSize).Lo, '');
end;

function TFileStreamEx.DoMap(APosition: Int64): Boolean;
begin
  FMapPos := CalcPos(APosition);
  FMapSize := Min(FMaxSize - FMapPos, FViewSize);
  if Assigned(FMapBuffer) then
  begin
    UnmapViewOfFile(FMapBuffer);
    FMapBuffer := nil;
  end;
  if FMapHandle <> 0 then
    FMapBuffer := MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS,
      Int64Rec(FMapPos).Hi, Int64Rec(FMapPos).Lo, FMapSize);
  Result := Assigned(FMapBuffer);
end;

procedure TFileStreamEx.SetSize(NewSize: LongInt);
begin
  SetSize(Int64(NewSize));
end;

procedure TFileStreamEx.SetSize(const NewSize: Int64);
var
  OldPosition: NativeInt;
begin
  OldPosition := FPosition;
  if NewSize <= FMaxSize then
    FSize := NewSize;
  if OldPosition > NewSize then
    Seek(0, soEnd);
end;

function TFileStreamEx.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result := 0;
  if (FPosition >= 0) and (Count >= 0) then
  begin
    if FSize - FPosition > 0 then
    begin
      if (Assigned(FMapBuffer) = False) or
        (InRange(FPosition, FMapPos, FMapPos + FMapSize - 1) = False) then
        if not DoMap(FPosition) then
          exit(0);
      if FSize > Count + FPosition then
        Result := Count
      else
        Result := FSize - FPosition;
      Result := Min(Result, FMapSize + FMapPos - FPosition);
      Move((PByte(FMapBuffer) + NativeInt(FPosition - FMapPos))^,
        Buffer, Result);
      Inc(FPosition, Result);
    end;
  end;
end;

function TFileStreamEx.Write(const Buffer; Count: LongInt): LongInt;
var
  LCount: LongInt;
begin
  Result := 0;
  LCount := Count;
  if (FPosition >= 0) and (LCount >= 0) then
  begin
    if FPosition + LCount > FMaxSize then
      IncSize(FPosition + LCount);
    if (Assigned(FMapBuffer) = False) or
      (InRange(FPosition, FMapPos, FMapPos + FMapSize - 1) = False) then
      if not DoMap(FPosition) then
        exit(0);
    LCount := Min(LCount, FMapSize + FMapPos - FPosition);
    Move(Buffer, (PByte(FMapBuffer) + NativeInt(FPosition - FMapPos))^, LCount);
    Inc(FPosition, LCount);
    if FPosition > FSize then
      FSize := FPosition;
    Result := LCount;
  end;
end;

function TFileStreamEx.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := Min(FPosition, FMaxSize);
end;

function TFileStreamEx.Map(APosition: Int64; ASize: NativeInt): Pointer;
begin
  Result := nil;
  FMapPos := CalcPos(APosition);
  FMapSize := Min(FMaxSize - FMapPos, ASize);
  if Assigned(FMapBuffer) then
  begin
    UnmapViewOfFile(FMapBuffer);
    FMapBuffer := nil;
  end;
  if FMapHandle <> 0 then
    FMapBuffer := MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS,
      Int64Rec(FMapPos).Hi, Int64Rec(FMapPos).Lo, FMapSize);
  Result := FMapBuffer;
end;

function TFileStreamEx.CopyTo(Dest: TStream; Count: Int64): Int64;
var
  LCount: LongInt;
  LSize: Int64;
begin
  if Count <= 0 then
  begin
    FPosition := 0;
    LSize := FSize;
  end
  else
    LSize := Count;
  while LSize > 0 do
    if FPosition >= 0 then
    begin
      if FPosition + LSize > FMaxSize then
        IncSize(FPosition + LSize);
      if (Assigned(FMapBuffer) = False) or
        (InRange(FPosition, FMapPos, FMapPos + FMapSize - 1) = False) then
        if not DoMap(FPosition) then
          exit;
      LCount := Min(LSize, FMapSize + FMapPos - FPosition);
      Dest.WriteBuffer((PByte(FMapBuffer) + NativeInt(FPosition - FMapPos))
        ^, LCount);
      Inc(FPosition, LCount);
      if FPosition > FSize then
        FSize := FPosition;
      Dec(LSize, LCount);
    end;
end;

procedure TFileStreamEx.Update;
var
  LSize: Int64;
begin
  if Assigned(FMapBuffer) then
  begin
    UnmapViewOfFile(FMapBuffer);
    FMapBuffer := nil;
  end;
  CloseHandleEx(FMapHandle);
  FMaxSize := FSize;
  FStream.Size := FMaxSize;
  if FMaxSize > 0 then
    FMapHandle := CreateFileMapping(FStream.Handle, nil, PAGE_READWRITE,
      Int64Rec(FMaxSize).Hi, Int64Rec(FMaxSize).Lo, '');
end;

procedure TFileStreamEx.Fill(Value: Byte; Count: Int64);
var
  LCount: LongInt;
  LSize: Int64;
begin
  LSize := Count;
  while LSize > 0 do
    if FPosition >= 0 then
    begin
      if FPosition + LSize > FMaxSize then
        IncSize(FPosition + LSize);
      if (Assigned(FMapBuffer) = False) or
        (InRange(FPosition, FMapPos, FMapPos + FMapSize - 1) = False) then
        if not DoMap(FPosition) then
          exit;
      LCount := Min(LSize, FMapSize + FMapPos - FPosition);
      FillChar((PByte(FMapBuffer) + NativeInt(FPosition - FMapPos))^,
        LCount, Value);
      Inc(FPosition, LCount);
      if FPosition > FSize then
        FSize := FPosition;
      Dec(LSize, LCount);
    end;
end;

constructor TDirInputStream.Create(const APath: String);
begin
  inherited Create;
  FState := TState.iNone;
  FPath := TPath.GetFullPath(APath);
  if FileExists(FPath) then
    FBaseDir := ExtractFilePath(TPath.GetFullPath(FPath))
  else if DirectoryExists(FPath) then
    FBaseDir := IncludeTrailingPathDelimiter(TPath.GetFullPath(FPath))
  else
    FBaseDir := ExtractFilePath(TPath.GetFullPath(FPath));
  FList := GetFileList([FPath], True);
  FCount := Length(FList);
  if FCount = 0 then
    raise EFOpenError.CreateRes(@SEmptyPath);
  FIndex := -1;
  FStream := nil;
end;

destructor TDirInputStream.Destroy;
begin
  if Assigned(FStream) then
    FStream.Free;
  FStream := nil;
  inherited Destroy;
end;

function TDirInputStream.Read(var Buffer; Count: LongInt): LongInt;
var
  LCount: Integer;
begin
  Result := 0;
  if Count <= 0 then
    exit;
  if FState = TState.iNone then
  begin
    if Succ(FIndex) >= FCount then
      exit;
    Inc(FIndex);
    FBytes := BytesOf(ReplaceText(FList[FIndex], FBaseDir, ''));
    FLength := Length(FBytes);
    FPosition := 0;
    FSize := FileSize(FList[FIndex]);
    FState := TState.iLength;
  end;
  if FState = TState.iLength then
    if FPosition < FLength.Size then
    begin
      LCount := Min(FLength.Size - FPosition, Count);
      Move(WordRec(FLength).Bytes[FPosition], Buffer, LCount);
      Inc(FPosition, LCount);
      if FPosition = FLength.Size then
      begin
        FState := TState.iFilename;
        FPosition := 0;
      end;
      exit(LCount);
    end;
  if FState = TState.iFilename then
    if FPosition < FLength then
    begin
      LCount := Min(FLength - FPosition, Count);
      Move(FBytes[FPosition], Buffer, LCount);
      Inc(FPosition, LCount);
      if FPosition = FLength then
      begin
        FState := TState.iSize;
        FPosition := 0;
      end;
      exit(LCount);
    end;
  if FState = TState.iSize then
    if FPosition < FSize.Size then
    begin
      LCount := Min(FSize.Size - FPosition, Count);
      Move(Int64Rec(FSize).Bytes[FPosition], Buffer, LCount);
      Inc(FPosition, LCount);
      if FPosition = FSize.Size then
      begin
        if FSize = 0 then
          FState := TState.iNone
        else
        begin
          FState := TState.iData;
          FPosition := 0;
          FStream := TFileStream.Create(FList[FIndex], fmShareDenyNone);
        end;
      end;
      exit(LCount);
    end;
  if FState = TState.iData then
    if FPosition < FSize then
    begin
      LCount := Min(FSize - FPosition, Count);
      LCount := FStream.Read(Buffer, LCount);
      Inc(FPosition, LCount);
      if FPosition = FSize then
      begin
        FState := TState.iNone;
        FStream.Free;
        FStream := nil;
      end;
      exit(LCount);
    end;
end;

constructor TDirOutputStream.Create(const APath: String);
begin
  inherited Create;
  FState := TState.oNone;
  FPath := IncludeTrailingPathDelimiter(TPath.GetFullPath(APath));
  FStream := nil;
end;

destructor TDirOutputStream.Destroy;
begin
  if Assigned(FStream) then
    FStream.Free;
  FStream := nil;
  inherited Destroy;
end;

function TDirOutputStream.Write(const Buffer; Count: LongInt): LongInt;
var
  LCount: Integer;
  LStr: String;
begin
  Result := 0;
  if Count <= 0 then
    exit;
  if FState = TState.oNone then
  begin
    FPosition := 0;
    FState := TState.oLength;
  end;
  if FState = TState.oLength then
    if FPosition < FLength.Size then
    begin
      LCount := Min(FLength.Size - FPosition, Count);
      Move(Buffer, WordRec(FLength).Bytes[FPosition], LCount);
      Inc(FPosition, LCount);
      if FPosition = FLength.Size then
      begin
        SetLength(FBytes, FLength);
        FState := TState.oFilename;
        FPosition := 0;
      end;
      exit(LCount);
    end;
  if FState = TState.oFilename then
    if FPosition < FLength then
    begin
      LCount := Min(FLength - FPosition, Count);
      Move(Buffer, FBytes[FPosition], LCount);
      Inc(FPosition, LCount);
      if FPosition = FLength then
      begin
        FState := TState.oSize;
        FPosition := 0;
      end;
      exit(LCount);
    end;
  if FState = TState.oSize then
    if FPosition < FSize.Size then
    begin
      LCount := Min(FSize.Size - FPosition, Count);
      Move(Buffer, Int64Rec(FSize).Bytes[FPosition], LCount);
      Inc(FPosition, LCount);
      if FPosition = FSize.Size then
      begin
        LStr := FPath + StringOf(FBytes);
        if not DirectoryExists(ExtractFilePath(LStr)) then
          ForceDirectories(ExtractFilePath(LStr));
        FStream := TFileStreamEx.Create(LStr, $100000);
        if FSize = 0 then
        begin
          FState := TState.oNone;
          FStream.Free;
          FStream := nil;
        end
        else
        begin
          FState := TState.oData;
          FPosition := 0;
        end;
      end;
      exit(LCount);
    end;
  if FState = TState.oData then
    if FPosition < FSize then
    begin
      LCount := Min(FSize - FPosition, Count);
      LCount := FStream.Write(Buffer, LCount);
      Inc(FPosition, LCount);
      if FPosition = FSize then
      begin
        FState := TState.oNone;
        FStream.Free;
        FStream := nil;
      end;
      exit(LCount);
    end;
end;

constructor TDownloadStream.Create(Url: string);
begin
  inherited Create;
  FUrl := Url;
  FPosition := 0;
  FSize := 0;
  FNetHTTPClient := TNetHTTPClient.Create(nil);
  FNetHTTPClient.Asynchronous := False;
  FNetHTTPClient.OnReceiveData := NetHTTPClientReceiveData;
  FNetHTTPClient.Get(FUrl);
  FNetHTTPClient.OnReceiveData := nil;
  FMemoryStream := TMemoryStream.Create;
  FMemoryStream.Size := FChunkSize;
end;

destructor TDownloadStream.Destroy;
begin
  FMemoryStream.Free;
  FNetHTTPClient.Free;
  inherited Destroy;
end;

procedure TDownloadStream.NetHTTPClientReceiveData(const Sender: TObject;
  AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  FSize := AContentLength;
  Abort := True;
end;

function TDownloadStream.Read(var Buffer; Count: LongInt): LongInt;
var
  Res: IHTTPResponse;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    if FSize - FPosition > 0 then
    begin
      if FSize > Count + FPosition then
        Result := Count
      else
        Result := FSize - FPosition;
      Result := Min(Result, FChunkSize);
      FMemoryStream.Position := 0;
      Res := FNetHTTPClient.GetRange(FUrl, FPosition, FPosition + Result - 1,
        FMemoryStream);
      Result := Res.ContentLength;
      Move(FMemoryStream.Memory^, Buffer, Result);
      Inc(FPosition, Result);
      exit;
    end;
  end;
  Result := 0;
end;

function TDownloadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

constructor TBufferedStream.Create(Stream: TStream; ReadMode: Boolean;
  BufferSize: Integer);
begin
  inherited Create;
  Instance := Stream;
  FReadMode := ReadMode;
  GetMem(FMemory, BufferSize);
  FBufferSize := BufferSize;
  FBufPos := 0;
  if FReadMode then
    FBufSize := Instance.Read(FMemory^, FBufferSize)
  else
    FBufSize := 0;
end;

destructor TBufferedStream.Destroy;
begin
  Flush;
  FreeMem(FMemory);
  Instance.Free;
  inherited Destroy;
end;

function TBufferedStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TBufferedStream.Read(var Buffer; Count: Integer): Integer;
var
  I, FCount: Integer;
  FSrc, FDest: PByte;
begin
  if FReadMode = False then
    raise EReadError.CreateRes(@SReadError);
  Result := 0;
  FCount := Count;
  if (Count <= 0) or (FBufSize = 0) then
    exit;
  while (FCount > 0) and (FBufSize - FBufPos > 0) do
  begin
    FSrc := FMemory + FBufPos;
    FDest := PByte(@Buffer) + (Count - FCount);
    if FCount > (FBufSize - FBufPos) then
      I := (FBufSize - FBufPos)
    else
      I := FCount;
    case I of
      sizeof(Byte):
        PByte(FDest)^ := PByte(FSrc)^;
      sizeof(Word):
        PWord(FDest)^ := PWord(FSrc)^;
      sizeof(cardinal):
        PCardinal(FDest)^ := PCardinal(FSrc)^;
      sizeof(UInt64):
        PUInt64(FDest)^ := PUInt64(FSrc)^;
    else
      Move(FSrc^, FDest^, I);
    end;
    Dec(FCount, I);
    Inc(FBufPos, I);
    if FBufPos = FBufSize then
    begin
      FBufPos := 0;
      FBufSize := Instance.Read(FMemory^, FBufferSize);
    end;
  end;
  Result := Count - FCount;
  Inc(FSize, Result);
end;

function TBufferedStream.Write(const Buffer; Count: Integer): Integer;
var
  I, FCount: Integer;
  FSrc, FDest: PByte;
begin
  if FReadMode = True then
    raise EWriteError.CreateRes(@SWriteError);
  Result := 0;
  if Count <= 0 then
    exit;
  FCount := Count;
  while (FCount > 0) do
  begin
    FSrc := PByte(@Buffer) + (Count - FCount);
    FDest := FMemory + FBufSize;
    if (FBufSize = 0) and (FCount >= FBufferSize) then
    begin
      Instance.WriteBuffer(FSrc^, FBufferSize);
      Dec(FCount, FBufferSize);
    end
    else if (FBufSize = FBufferSize) then
    begin
      Instance.WriteBuffer(FMemory^, FBufSize);
      FBufSize := 0;
    end
    else
    begin
      if FCount > (FBufferSize - FBufSize) then
        I := (FBufferSize - FBufSize)
      else
        I := FCount;
      case I of
        sizeof(Byte):
          PByte(FDest)^ := PByte(FSrc)^;
        sizeof(Word):
          PWord(FDest)^ := PWord(FSrc)^;
        sizeof(cardinal):
          PCardinal(FDest)^ := PCardinal(FSrc)^;
        sizeof(UInt64):
          PUInt64(FDest)^ := PUInt64(FSrc)^;
      else
        Move(FSrc^, FDest^, I);
      end;
      Dec(FCount, I);
      Inc(FBufSize, I);
    end;
  end;
  Result := Count - FCount;
  Inc(FSize, Result);
end;

procedure TBufferedStream.Flush;
begin
  if FReadMode = False then
  begin
    Instance.WriteBuffer(FMemory^, FBufSize);
    FBufSize := 0;
  end;
end;

constructor TProcessStream.Create(AExecutable, ACommandLine, AWorkDir: String;
  AInput: TStream; AOutput: TStream; AError: TStream);
begin
  inherited Create;
  FInput := AInput;
  FOutput := AOutput;
  FError := AError;
  FExecutable := AExecutable;
  FCommandLine := ACommandLine;
  FWorkDir := AWorkDir;
  FInSize := 0;
  FOutSize := 0;
  FTask := TTask.Create;
  FTask2 := TTask.Create;
end;

destructor TProcessStream.Destroy;
begin
  CloseHandleEx(FStdinr);
  CloseHandleEx(FStdinw);
  CloseHandleEx(FStdoutr);
  CloseHandleEx(FStdoutw);
  CloseHandleEx(FStderrr);
  CloseHandleEx(FStderrw);
  CloseHandleEx(FProcessInfo.hProcess);
  FTask.Free;
  FTask2.Free;
  inherited Destroy;
end;

function TProcessStream.Read(var Buffer; Count: LongInt): LongInt;
var
  BytesRead: DWORD;
begin
  Result := 0;
  if Assigned(FOutput) then
    raise EReadError.CreateRes(@SReadError);
  if ReadFile(FStdoutr, Buffer, Count, BytesRead, nil) then
    Result := BytesRead;
  Inc(FOutSize, Result);
end;

function TProcessStream.Write(const Buffer; Count: LongInt): LongInt;
var
  BytesWritten: DWORD;
  Res: Boolean;
begin
  Result := 0;
  if Assigned(FInput) then
    raise EWriteError.CreateRes(@SWriteError);
  if Count = 0 then
    CloseHandleEx(FStdinw)
  else if WriteFile(FStdinw, Buffer, Count, BytesWritten, nil) then
    Result := BytesWritten;
  Inc(FInSize, Result);
end;

procedure TProcessStream.ExecReadTask;
const
  BufferSize = 65536;
var
  Buffer: array [0 .. BufferSize - 1] of Byte;
  BytesRead: DWORD;
begin
  while ReadFile(FStdoutr, Buffer[0], Length(Buffer), BytesRead, nil) and
    (BytesRead > 0) do
  begin
    Inc(FOutSize, BytesRead);
    FOutput.WriteBuffer(Buffer[0], BytesRead);
  end;
  CloseHandleEx(FStdoutr);
end;

procedure TProcessStream.ExecWriteTask;
const
  BufferSize = 65536;
var
  Buffer: array [0 .. BufferSize - 1] of Byte;
  BytesWritten: DWORD;
begin
  BytesWritten := FInput.Read(Buffer[0], BufferSize);
  while WriteFile(FStdinw, Buffer[0], BytesWritten, BytesWritten, nil) and
    (BytesWritten > 0) do
  begin
    Inc(FInSize, BytesWritten);
    BytesWritten := FInput.Read(Buffer[0], BufferSize);
  end;
  CloseHandleEx(FStdinw);
end;

procedure TProcessStream.ExecErrorTask;
const
  BufferSize = 65536;
var
  Buffer: array [0 .. BufferSize - 1] of Byte;
  BytesRead: DWORD;
begin
  while ReadFile(FStderrr, Buffer[0], Length(Buffer), BytesRead, nil) and
    (BytesRead > 0) do
    if Assigned(FError) then
      FError.WriteBuffer(Buffer[0], BytesRead);
  CloseHandleEx(FStderrr);
end;

function TProcessStream.Execute: Boolean;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
var
  StartupInfo: TStartupInfo;
  dwExitCode: DWORD;
  LWorkDir: PChar;
begin
  Result := False;
  CreatePipe(FStdinr, FStdinw, @PipeSecurityAttributes, 0);
  CreatePipe(FStdoutr, FStdoutw, @PipeSecurityAttributes, 0);
  CreatePipe(FStderrr, FStderrw, @PipeSecurityAttributes, 0);
  SetHandleInformation(FStdinw, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(FStdoutr, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(FStderrr, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := FStdinr;
  StartupInfo.hStdOutput := FStdoutw;
  StartupInfo.hStdError := FStderrw;
  ZeroMemory(@FProcessInfo, sizeof(FProcessInfo));
  if FWorkDir <> '' then
    LWorkDir := Pointer(FWorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + FExecutable + '" ' + FCommandLine), nil,
    nil, True, 0, nil, LWorkDir, StartupInfo, FProcessInfo) then
  begin
    CloseHandleEx(FProcessInfo.hThread);
    CloseHandleEx(FStdinr);
    CloseHandleEx(FStdoutw);
    CloseHandleEx(FStderrw);
    FTask2.Perform(ExecErrorTask);
    FTask2.Start;
    if Assigned(FOutput) and not Assigned(FInput) then
    begin
      FTask.Perform(ExecReadTask);
      FTask.Start;
      Result := True;
    end
    else if Assigned(FInput) and not Assigned(FOutput) then
    begin
      FTask.Perform(ExecWriteTask);
      FTask.Start;
      Result := True;
    end
    else if Assigned(FInput) and Assigned(FOutput) then
    begin
      FTask.Perform(ExecReadTask);
      FTask.Start;
      ExecWriteTask;
      FTask.Wait;
      WaitForSingleObject(FProcessInfo.hProcess, INFINITE);
      GetExitCodeProcess(FProcessInfo.hProcess, dwExitCode);
      CloseHandleEx(FProcessInfo.hProcess);
      if FTask.Status <> TThreadStatus.tsErrored then
        FTask.RaiseLastError;
      Result := dwExitCode = 0;
    end;
  end
  else
  begin
    CloseHandleEx(FStdinr);
    CloseHandleEx(FStdinw);
    CloseHandleEx(FStdoutr);
    CloseHandleEx(FStdoutw);
    CloseHandleEx(FStderrr);
    CloseHandleEx(FStderrw);
    RaiseLastOSError;
  end;
end;

procedure TProcessStream.Wait;
begin
  WaitForSingleObject(FProcessInfo.hProcess, INFINITE);
end;

function TProcessStream.Done: Boolean;
var
  dwExitCode: DWORD;
begin
  Result := False;
  CloseHandleEx(FStdinw);
  CloseHandleEx(FStdoutr);
  CloseHandleEx(FStderrr);
  FTask.Wait;
  FTask2.Wait;
  WaitForSingleObject(FProcessInfo.hProcess, INFINITE);
  GetExitCodeProcess(FProcessInfo.hProcess, dwExitCode);
  CloseHandleEx(FProcessInfo.hProcess);
  if FTask.Status <> TThreadStatus.tsErrored then
    FTask.RaiseLastError;
  Result := dwExitCode = 0;
end;

function TProcessStream.Running: Boolean;
begin
  Result := WaitForSingleObject(FProcessInfo.hProcess, 0) = WAIT_TIMEOUT;
end;

constructor TStoreStream.Create(ASize: NativeInt);
begin
  inherited Create(False, GetMemory(ASize), ASize);
end;

destructor TStoreStream.Destroy;
begin
  if Assigned(FOnFull) then
    if Size > 0 then
      FOnFull(Self);
  if Assigned(FMemory) then
    FreeMemory(FMemory);
  inherited Destroy;
end;

function TStoreStream.Write(const Buffer; Count: Integer): Integer;
begin
  if FSize = FMaxSize then
  begin
    if Assigned(FOnFull) then
      FOnFull(Self);
    Position := 0;
    Size := 0;
  end;
  Result := inherited Write(Buffer, Count);
end;

procedure TStoreStream.Flush;
begin
  if Assigned(FOnFull) then
    if Size > 0 then
      FOnFull(Self);
  Position := 0;
  Size := 0;
end;

constructor TCacheReadStream.Create(Input, Cache: TStream;
  AComp: TCacheCompression);
begin
  inherited Create;
  FSync.Init;
  FInput := Input;
  FCache := Cache;
  FPosition1 := 0;
  FPosition2 := 0;
  FUsedSize := 0;
  if Assigned(FCache) then
    FMaxSize := FCache.Size
  else
    FMaxSize := 0;
  FDone := False;
  FComp := AComp;
  FTask := TTask.Create;
  FTask.Perform(CacheMemory);
  if FMaxSize > FBufferSize then
  begin
    FStorage1 := TStoreStream.Create(FBufferSize);
    FStorage1.OnFull := FOnFull;
    FStorage2 := TMemoryStreamEx.Create(False, GetMemory(FBufferSize),
      FBufferSize);
    case FComp of
      ccLZ4:
        FCompBufferSize := LZ4_compressBound(FBufferSize);
      ccZSTD:
        begin
          FCCtx := ZSTD_createCCtx;
          FDCtx := ZSTD_createDCtx;
          FCompBufferSize := ZSTD_compressBound(FBufferSize);
        end;
    else
      FCompBufferSize := FBufferSize;
    end;
    if FComp > ccNone then
      GetMem(FCompBuffer, FCompBufferSize);
    FTask.Start;
  end;
end;

destructor TCacheReadStream.Destroy;
begin
  FDone := True;
  if FMaxSize > FBufferSize then
  begin
    FTask.Wait;
    case FComp of
      ccZSTD:
        begin
          ZSTD_freeCCtx(FCCtx);
          ZSTD_freeDCtx(FDCtx);
        end;
    end;
    FStorage1.Free;
    if Assigned(FStorage2.Memory) then
      FreeMemory(FStorage2.Memory);
    FStorage2.Free;
    if FComp > ccNone then
      FreeMem(FCompBuffer);
  end;
  FTask.Free;
  if FMaxSize > FBufferSize then
    FCache.Free;
  FSync.Done;
  inherited Destroy;
end;

procedure TCacheReadStream.CacheMemory;
begin
  CopyStream(FInput, FStorage1, Int64.MaxValue, FCallback);
  if not FDone then
  begin
    FStorage1.Flush;
    FDone := True;
  end;
end;

function TCacheReadStream.Read(var Buffer; Count: Integer): Integer;
var
  I: Int64;
  J: Integer;

  procedure DoRead;
  begin
    J := I;
    if (FPosition2 mod FMaxSize) + FCompBufferSize + J.Size >= FMaxSize then
      FCache.ReadBuffer(FStorage2.Memory^, I)
    else
    begin
      if FComp > ccNone then
      begin
        FCache.ReadBuffer(J, J.Size);
        FCache.ReadBuffer(FCompBuffer^, J);
        I := J.Size + J;
      end;
      case FComp of
        ccLZ4:
          J := LZ4_decompress_safe(FCompBuffer, FStorage2.Memory, J,
            FCompBufferSize);
        ccZSTD:
          J := ZSTD_decompressDCtx(FDCtx, FStorage2.Memory, FCompBufferSize,
            FCompBuffer, J);
      else
        FCache.ReadBuffer(FStorage2.Memory^, I);
      end;
    end;
    FStorage2.Size := J;
    AtomicDecrement(FCached, J);
  end;

begin
  if FMaxSize <= FBufferSize then
  begin
    Result := FInput.Read(Buffer, Count);
    exit;
  end;
  if Count <= 0 then
    exit(0);
  if FStorage2.Position = FStorage2.Size then
  begin
    AtomicExchange(I, FUsedSize);
    while I = 0 do
    begin
      Sleep(1);
      AtomicExchange(I, FUsedSize);
      if FDone then
        break;
    end;
    I := Min(FBufferSize, Min(I, FMaxSize - (FPosition2 mod FMaxSize)));
    if I <= 0 then
      exit(0);
    FSync.Lock;
    try
      FCache.Position := FPosition2 mod FMaxSize;
      DoRead;
    finally
      FSync.UnLock;
    end;
    Inc(FPosition2, I);
    AtomicDecrement(FUsedSize, I);
    FStorage2.Position := 0;
  end;
  Result := FStorage2.Read(Buffer, Count);
end;

function TCacheReadStream.FCallback(ASize: Int64): Boolean;
begin
  Result := FDone = False;
end;

procedure TCacheReadStream.FOnFull(Stream: TStream);
var
  I: Int64;
  J, X: Integer;
  Ptr: PByte;
begin
  X := 0;
  while X < Stream.Size do
  begin
    AtomicExchange(I, FUsedSize);
    while FMaxSize - I < FBufferSize do
    begin
      Sleep(1);
      AtomicExchange(I, FUsedSize);
      if FDone then
        exit;
    end;
    I := Min(Stream.Size - X, Min(FMaxSize - I,
      FMaxSize - (FPosition1 mod FMaxSize)));
    AtomicIncrement(FCached, I);
    Ptr := PByte(TStoreStream(Stream).Memory) + X;
    Inc(X, I);
    FSync.Lock;
    try
      FCache.Position := FPosition1 mod FMaxSize;
      if (FPosition1 mod FMaxSize) + FCompBufferSize + J.Size >= FMaxSize then
        FCache.WriteBuffer(Pointer(Ptr)^, I)
      else
      begin
        case FComp of
          ccLZ4:
            J := LZ4_compress_fast(Pointer(Ptr), FCompBuffer, I,
              FCompBufferSize, 1);
          ccZSTD:
            J := ZSTD_compressCCtx(FCCtx, FCompBuffer, FCompBufferSize,
              Pointer(Ptr), I, 1);
        else
          FCache.WriteBuffer(Pointer(Ptr)^, I);
        end;
        if FComp > ccNone then
        begin
          FCache.WriteBuffer(J, J.Size);
          FCache.WriteBuffer(FCompBuffer^, J);
          I := J.Size + J;
        end;
      end;
    finally
      FSync.UnLock;
    end;
    Inc(FPosition1, I);
    AtomicIncrement(FUsedSize, I);
  end;
end;

function TCacheReadStream.Cached(Compressed: PInt64): Int64;
begin
  AtomicExchange(Result, FUsedSize);
  if Assigned(Compressed) then
    if FComp > ccNone then
      Compressed^ := FCached
    else
      Compressed^ := 0;
end;

constructor TCacheWriteStream.Create(Output, Cache: TStream;
  AComp: TCacheCompression);
begin
  inherited Create;
  FSync.Init;
  FOutput := Output;
  FCache := Cache;
  FPosition1 := 0;
  FPosition2 := 0;
  FUsedSize := 0;
  if Assigned(FCache) then
    FMaxSize := FCache.Size
  else
    FMaxSize := 0;
  FDone := False;
  FComp := AComp;
  FTask := TTask.Create;
  FTask.Perform(CacheMemory);
  if FMaxSize > FBufferSize then
  begin
    GetMem(FBuffer, FBufferSize);
    FStorage := TStoreStream.Create(FBufferSize);
    FStorage.OnFull := FOnFull;
    case FComp of
      ccLZ4:
        FCompBufferSize := LZ4_compressBound(FBufferSize);
      ccZSTD:
        begin
          FCCtx := ZSTD_createCCtx;
          FDCtx := ZSTD_createDCtx;
          FCompBufferSize := ZSTD_compressBound(FBufferSize);
        end;
    else
      FCompBufferSize := FBufferSize;
    end;
    if FComp > ccNone then
      GetMem(FCompBuffer, FCompBufferSize);
    FTask.Start;
  end;
  FCached := 0;
end;

destructor TCacheWriteStream.Destroy;
var
  I: Int64;
begin
  if FMaxSize > FBufferSize then
  begin
    FStorage.Free;
    FDone := True;
    FTask.Wait;
    case FComp of
      ccZSTD:
        begin
          ZSTD_freeCCtx(FCCtx);
          ZSTD_freeDCtx(FDCtx);
        end;
    end;
    FreeMem(FBuffer);
    if FComp > ccNone then
      FreeMem(FCompBuffer);
  end;
  FTask.Free;
  if FMaxSize > FBufferSize then
    FCache.Free;
  FSync.Done;
  inherited Destroy;
end;

procedure TCacheWriteStream.CacheMemory;
var
  I: Int64;
  J: Integer;

  procedure DoRead;
  begin
    J := I;
    if (FPosition1 mod FMaxSize) + FCompBufferSize + J.Size >= FMaxSize then
      FCache.ReadBuffer(FBuffer^, I)
    else
    begin
      if FComp > ccNone then
      begin
        FCache.ReadBuffer(J, J.Size);
        FCache.ReadBuffer(FCompBuffer^, J);
        I := J.Size + J;
      end;
      case FComp of
        ccLZ4:
          J := LZ4_decompress_safe(FCompBuffer, FBuffer, J, FCompBufferSize);
        ccZSTD:
          J := ZSTD_decompressDCtx(FDCtx, FBuffer, FCompBufferSize,
            FCompBuffer, J);
      else
        FCache.ReadBuffer(FBuffer^, I);
      end;
    end;
    AtomicDecrement(FCached, J);
  end;

begin
  while True do
  begin
    AtomicExchange(I, FUsedSize);
    while I = 0 do
    begin
      Sleep(1);
      AtomicExchange(I, FUsedSize);
      if FDone then
        break;
    end;
    I := Min(FBufferSize, Min(I, FMaxSize - (FPosition1 mod FMaxSize)));
    if I <= 0 then
      exit;
    FSync.Lock;
    try
      FCache.Position := FPosition1 mod FMaxSize;
      DoRead;
    finally
      FSync.UnLock;
    end;
    FOutput.WriteBuffer(FBuffer^, J);
    Inc(FPosition1, I);
    AtomicDecrement(FUsedSize, I);
    if FDone and (FPosition1 = FPosition2) then
      break;
  end;
end;

function TCacheWriteStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  if FMaxSize < FBufferSize then
  begin
    FOutput.WriteBuffer(Buffer, Count);
    exit(Count);
  end;
  if Count <= 0 then
    exit(0);
  Result := FStorage.Write(Buffer, Count);
end;

procedure TCacheWriteStream.FOnFull(Stream: TStream);
var
  I: Int64;
  J, X, Y: Integer;
  Ptr: PByte;
begin
  X := 0;
  while X < Stream.Size do
  begin
    AtomicExchange(I, FUsedSize);
    while FMaxSize - I < FBufferSize do
    begin
      Sleep(1);
      AtomicExchange(I, FUsedSize);
    end;
    I := Min(Stream.Size - X, Min(FMaxSize - I,
      FMaxSize - (FPosition2 mod FMaxSize)));
    AtomicIncrement(FCached, I);
    Ptr := PByte(TStoreStream(Stream).Memory) + X;
    Inc(X, I);
    FSync.Lock;
    try
      FCache.Position := FPosition2 mod FMaxSize;
      if (FPosition2 mod FMaxSize) + FCompBufferSize + J.Size >= FMaxSize then
        FCache.WriteBuffer(Ptr^, I)
      else
      begin
        case FComp of
          ccLZ4:
            J := LZ4_compress_fast(Pointer(Ptr), FCompBuffer, I,
              FCompBufferSize, 1);
          ccZSTD:
            J := ZSTD_compressCCtx(FCCtx, FCompBuffer, FCompBufferSize,
              Pointer(Ptr), I, 1);
        else
          FCache.WriteBuffer(Ptr^, I);
        end;
        if FComp > ccNone then
        begin
          FCache.WriteBuffer(J, J.Size);
          FCache.WriteBuffer(FCompBuffer^, J);
          I := J.Size + J;
        end;
      end;
    finally
      FSync.UnLock;
    end;
    Inc(FPosition2, I);
    AtomicIncrement(FUsedSize, I);
  end;
end;

function TCacheWriteStream.Cached(Compressed: PInt64): Int64;
begin
  AtomicExchange(Result, FUsedSize);
  if Assigned(Compressed) then
    if FComp > ccNone then
      Compressed^ := FCached
    else
      Compressed^ := 0;
end;

constructor TDataStore1.Create(AInput: TStream; ADynamic: Boolean;
  ASlots, ASize: NativeInt; ATempFile: String);
var
  I: Integer;
begin
  inherited Create;
  FSync.Init;
  FInput := AInput;
  FTemp := nil;
  FTempFile := ATempFile;
  FTempPos := 0;
  FDynamic := ADynamic;
  FIndex := 0;
  FSlots := ASlots;
  FSize := ASize;
  if FDynamic then
  begin
    FMemPtr := GetMemory((FSlots + 1) * FSize);
    FMemStm := TMemoryStreamEx.Create(False, FMemPtr, (FSlots + 1) * FSize);
    FMemStm.Size := (FSlots + 1) * FSize;
  end
  else
  begin
    FMemPtr := GetMemory(FSlots * FSize);
    FMemStm := TMemoryStreamEx.Create(False, FMemPtr, FSlots * FSize);
    FMemStm.Size := FSlots * FSize;
  end;
  SetLength(FMemData, FSlots);
  SetLength(FPositions, FSlots);
  for I := Low(FMemData) to High(FMemData) do
  begin
    if FDynamic then
      FMemData[I] := TMemoryStreamEx.Create(False,
        (PByte(FMemStm.Memory) + (I * FSize)), FSize * 2)
    else
      FMemData[I] := TMemoryStreamEx.Create(False,
        (PByte(FMemStm.Memory) + (I * FSize)), FSize);
    FPositions[I] := (I * FSize) - (Length(FMemData) * FSize);
  end;
  FDone := False;
  FFirstRead := True;
  FLastRead := False;
end;

destructor TDataStore1.Destroy;
var
  I: Integer;
begin
  if Assigned(FTemp) then
  begin
    FTemp.Free;
    DeleteFile(FTempFile);
  end;
  for I := Low(FMemData) to High(FMemData) do
    FMemData[I].Free;
  FMemStm.Free;
  FreeMemory(FMemPtr);
  FSync.Done;
  inherited Destroy;
end;

procedure TDataStore1.ChangeInput(AInput: TStream);
var
  I: Integer;
begin
  FInput := AInput;
  FIndex := 0;
  if FDynamic then
    FMemStm.Size := (FSlots + 1) * FSize
  else
    FMemStm.Size := FSlots * FSize;
  for I := Low(FMemData) to High(FMemData) do
  begin
    FMemData[I].Position := 0;
    FMemData[I].Size := 0;
    FPositions[I] := (I * FSize) - (Length(FMemData) * FSize);
  end;
  FDone := False;
  FFirstRead := True;
  FLastRead := False;
end;

function TDataStore1.Read(Index: Integer; Position: NativeInt; var Buffer;
  Count: Integer): Integer;
const
  BuffSize = 65536;
var
  Buff: array [0 .. BuffSize - 1] of Byte;
  I: Integer;
  LPos: NativeInt;
  LMemSize: NativeInt;
begin
  Result := 0;
  LPos := Position;
  LMemSize := 0;
  for I := Index to High(FMemData) do
    Inc(LMemSize, IfThen(I = High(FMemData), ActualSize(I), Size(I)));
  if LPos < LMemSize then
  begin
    I := Min(LMemSize - LPos, Count);
    Move((PByte(FMemData[Index].Memory) + LPos)^, Buffer, I);
    Result := I;
  end
  else
  begin
    if Count = 0 then
      exit;
    FSync.Lock;
    try
      if not Assigned(FTemp) then
        FTemp := TFileStreamEx.Create(FTempFile, $100000);
      Dec(LPos, LMemSize);
      if LPos > FTemp.Size then
      begin
        FTemp.Position := FTemp.Size;
        while LPos > FTemp.Size do
        begin
          I := FInput.Read(Buff[0], BuffSize);
          if I = 0 then
            exit;
          FTemp.WriteBuffer(Buff[0], I);
        end;
      end;
      if (LPos = FTemp.Position) and (LPos = FTemp.Size) then
      begin
        I := FInput.Read(Buffer, Count);
        FTemp.WriteBuffer(Buffer, I);
        Result := I;
      end
      else
      begin
        FTemp.Position := LPos;
        Result := FTemp.Read(Buffer, Count)
      end;
    finally
      FSync.UnLock;
    end;
  end;
end;

function TDataStore1.Slot(Index: Integer): TMemoryStream;
begin
  Result := FMemData[Index];
end;

function TDataStore1.Position(Index: Integer): Int64;
begin
  Result := FPositions[Index];
end;

function TDataStore1.Size(Index: Integer): NativeInt;
begin
  Result := Min(FSize, FMemData[Index].Size);
end;

function TDataStore1.ActualSize(Index: Integer): NativeInt;
begin
  Result := FMemData[Index].Size;
end;

function TDataStore1.Slots: NativeInt;
begin
  Result := FSlots;
end;

function TDataStore1.Done: Boolean;
begin
  Result := FDone;
end;

procedure TDataStore1.Load;
var
  I: Integer;
  W, X: Int64;
begin
  for I := Low(FMemData) to High(FMemData) do
    Inc(FPositions[I], Length(FMemData) * FSize);
  if FDynamic then
  begin
    if FFirstRead then
    begin
      FMemStm.Position := 0;
      FFirstRead := False;
    end
    else
    begin
      W := Min(FSize, Max(0, FMemStm.Position - (FSlots * FSize)));
      Move((PByte(FMemStm.Memory) + (FSlots * FSize))^, FMemStm.Memory^, W);
      FMemStm.Position := W;
    end;
    while FMemStm.Position < FMemStm.Size do
    begin
      if Assigned(FTemp) and (FTempPos < FTemp.Size) then
      begin
        FTemp.Position := FTempPos;
        X := FTemp.Read(FBuffer[0], Min(FMemStm.Size - FMemStm.Position,
          FBufferSize));
        Inc(FTempPos, X);
        if FTempPos = FTemp.Size then
        begin
          FTempPos := 0;
          FTemp.Size := 0;
        end;
      end
      else
        X := FInput.Read(FBuffer[0], Min(FMemStm.Size - FMemStm.Position,
          FBufferSize));
      if X > 0 then
        FMemStm.WriteBuffer(FBuffer[0], X)
      else
      begin
        FLastRead := True;
        break;
      end;
    end;
    for I := Low(FMemData) to High(FMemData) do
      FMemData[I].Size := Min(FSize * 2,
        Max(0, FMemStm.Position - (I * FSize)));
  end
  else
  begin
    FMemStm.Position := 0;
    while FMemStm.Position < FMemStm.Size do
    begin
      if Assigned(FTemp) and (FTempPos < FTemp.Size) then
      begin
        FTemp.Position := FTempPos;
        X := FTemp.Read(FBuffer[0], Min(FMemStm.Size - FMemStm.Position,
          FBufferSize));
        Inc(FTempPos, X);
        if FTempPos = FTemp.Size then
        begin
          FTempPos := 0;
          FTemp.Size := 0;
        end;
      end
      else
        X := FInput.Read(FBuffer[0], Min(FMemStm.Size - FMemStm.Position,
          FBufferSize));
      if X > 0 then
        FMemStm.WriteBuffer(FBuffer[0], X)
      else
      begin
        FDone := True;
        break;
      end;
    end;
    for I := Low(FMemData) to High(FMemData) do
      FMemData[I].Size := Min(FSize, Max(0, FMemStm.Position - (I * FSize)));
  end;
  FDone := FMemData[0].Size = 0;
end;

procedure TDataStore1.LoadEx;
var
  W, X: Int64;
begin
  Inc(FPositions[FIndex], Length(FMemData) * FSize);
  if FDynamic then
  begin
    if FIndex = 0 then
    begin
      W := Min(FSize, Max(0, FMemStm.Position - (FSlots * FSize)));
      Move((PByte(FMemStm.Memory) + (FSlots * FSize))^, FMemStm.Memory^, W);
      FMemStm.Position := W;
    end;
    W := FMemStm.Position + FSize;
    while FMemStm.Position < W do
    begin
      if Assigned(FTemp) and (FTempPos < FTemp.Size) then
      begin
        FTemp.Position := FTempPos;
        X := FTemp.Read(FBuffer[0], Min(W - FMemStm.Position, FBufferSize));
        Inc(FTempPos, X);
        if FTempPos = FTemp.Size then
        begin
          FTempPos := 0;
          FTemp.Size := 0;
        end;
      end
      else
        X := FInput.Read(FBuffer[0], Min(W - FMemStm.Position, FBufferSize));
      if X > 0 then
        FMemStm.WriteBuffer(FBuffer[0], X)
      else
      begin
        FLastRead := True;
        break;
      end;
    end;
    FMemData[FIndex].Size :=
      Min(FSize * 2, Max(0, FMemStm.Position - (FIndex * FSize)));
  end
  else
  begin
    FMemStm.Position := FIndex * FSize;
    W := FMemStm.Position + FSize;
    while FMemStm.Position < W do
    begin
      if Assigned(FTemp) and (FTempPos < FTemp.Size) then
      begin
        FTemp.Position := FTempPos;
        X := FTemp.Read(FBuffer[0], Min(W - FMemStm.Position, FBufferSize));
        Inc(FTempPos, X);
        if FTempPos = FTemp.Size then
        begin
          FTempPos := 0;
          FTemp.Size := 0;
        end;
      end
      else
        X := FInput.Read(FBuffer[0], Min(W - FMemStm.Position, FBufferSize));
      if X > 0 then
        FMemStm.WriteBuffer(FBuffer[0], X)
      else
      begin
        FDone := True;
        break;
      end;
    end;
    FMemData[FIndex].Size :=
      Min(FSize, Max(0, FMemStm.Position - (FIndex * FSize)));
  end;
  Inc(FIndex);
  if FIndex = FSlots then
    FIndex := 0;
  FDone := FMemData[0].Size = 0;
end;

constructor TDataStore2.Create(ASlots: NativeInt);
var
  I: Integer;
begin
  inherited Create;
  FSlots := ASlots;
  SetLength(FMemData, FSlots);
  SetLength(FPositions, FSlots);
  SetLength(FSizes, FSlots);
  for I := Low(FMemData) to High(FMemData) do
  begin
    FMemData[I] := TMemoryStream.Create;
    FPositions[I] := 0;
    FSizes[I] := 0;
  end;
end;

destructor TDataStore2.Destroy;
var
  I: Integer;
begin
  for I := Low(FMemData) to High(FMemData) do
    FMemData[I].Free;
  inherited Destroy;
end;

function TDataStore2.Slot(Index: Integer): TMemoryStream;
begin
  Result := FMemData[Index];
end;

function TDataStore2.Position(Index: Integer): Int64;
begin
  Result := FPositions[Index];
end;

function TDataStore2.Size(Index: Integer): NativeInt;
begin
  Result := FSizes[Index];
end;

function TDataStore2.ActualSize(Index: Integer): NativeInt;
begin
  Result := FSizes[Index];
end;

function TDataStore2.Slots: NativeInt;
begin
  Result := FSlots;
end;

function TDataStore2.Done: Boolean;
begin
  Result := False;
end;

procedure TDataStore2.Load(Index: Integer; Memory: Pointer; Size: Integer);
begin
  FMemData[Index].WriteBuffer(Memory^, Size);
  Inc(FSizes[Index], Size);
end;

procedure TDataStore2.Reset(Index: Integer);
begin
  FMemData[Index].Position := 0;
  FSizes[Index] := 0;
end;

constructor TDataManager.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
  FStreamPos := FStream.Position;
  FStreamSize := 0;
end;

destructor TDataManager.Destroy;
begin
  inherited Destroy;
end;

procedure TDataManager.Add(ID: Integer; Size: Integer; Count: Integer);
var
  I: Integer;
  LBlockInfo: TBlockInfo;
begin
  if Count <= 0 then
    exit;
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (FSearchList[I].Count <= 0) and (Size <= FSearchList[I].FullSize) then
    begin
      FSearchList[I].ID := ID;
      FSearchList[I].CurrSize := 0;
      FSearchList[I].Count := Count;
      exit;
    end;
  end;
  LBlockInfo.ID := ID;
  LBlockInfo.Position := FStreamPos + FStreamSize;
  LBlockInfo.CurrSize := 0;
  LBlockInfo.FullSize := Size;
  LBlockInfo.Count := Count;
  Insert(LBlockInfo, FSearchList, Length(FSearchList));
  Inc(FStreamSize, Size);
end;

procedure TDataManager.Write(ID: Integer; Buffer: Pointer; Size: Integer);
var
  I: Integer;
begin
  if Size <= 0 then
    exit;
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (ID = FSearchList[I].ID) and (FSearchList[I].Count > 0) then
    begin
      if FSearchList[I].CurrSize + Size > FSearchList[I].FullSize then
        raise EWriteError.CreateRes(@SWriteError);
      FStream.Position := FSearchList[I].Position + FSearchList[I].CurrSize;
      FStream.WriteBuffer(Buffer^, Size);
      Inc(FSearchList[I].CurrSize, Size);
      exit;
    end;
  end;
  raise Exception.CreateRes(@SGenericItemNotFound);
end;

procedure TDataManager.CopyData(ID: Integer; Stream: TStream);
var
  I: Integer;
begin
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (ID = FSearchList[I].ID) and (FSearchList[I].Count > 0) then
    begin
      FStream.Position := FSearchList[I].Position;
      CopyStreamEx(FStream, Stream, FSearchList[I].CurrSize);
      Dec(FSearchList[I].Count);
      exit;
    end;
  end;
  raise Exception.CreateRes(@SGenericItemNotFound);
end;

function TDataManager.CopyData(ID: Integer; Data: Pointer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (ID = FSearchList[I].ID) and (FSearchList[I].Count > 0) then
    begin
      FStream.Position := FSearchList[I].Position;
      FStream.ReadBuffer(Data^, FSearchList[I].CurrSize);
      Result := FSearchList[I].CurrSize;
      Dec(FSearchList[I].Count);
      if FSearchList[I].Count = 0 then
        FSearchList[I].ID := -1;
      exit;
    end;
  end;
  raise Exception.CreateRes(@SGenericItemNotFound);
end;

procedure TDataManager.Update(ID: Integer; Count: Integer);
var
  I: Integer;
begin
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (ID = FSearchList[I].ID) then
    begin
      FSearchList[I].Count := Count;
      exit;
    end;
  end;
  raise Exception.CreateRes(@SGenericItemNotFound);
end;

procedure TDataManager.Reset(ID: Integer);
var
  I: Integer;
begin
  for I := Low(FSearchList) to High(FSearchList) do
  begin
    if (ID = FSearchList[I].ID) and (FSearchList[I].Count > 0) then
    begin
      FSearchList[I].CurrSize := 0;
      exit;
    end;
  end;
  raise Exception.CreateRes(@SGenericItemNotFound);
end;

constructor TArgParser.Create(Arguments: TStringDynArray);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FArgs, Length(Arguments));
  for I := Low(FArgs) to High(FArgs) do
    FArgs[I] := Arguments[I];
end;

destructor TArgParser.Destroy;
begin
  SetLength(FArgs, 0);
  inherited Destroy;
end;

procedure TArgParser.Add(Arguments: String);
var
  I: Integer;
  List: TStringDynArray;
begin
  if Arguments = '' then
    exit;
  List := DecodeStr(Arguments, ' ');
  for I := Low(List) to High(List) do
    Insert(List[I], FArgs, Length(FArgs));
end;

function TArgParser.AsString(Parameter: String; Index: Integer;
  Default: String): String;
var
  I, J: Integer;
begin
  Result := Default;
  J := 0;
  for I := Low(FArgs) to High(FArgs) do
    if FArgs[I].StartsWith(Parameter, False) then
    begin
      if J >= Index then
      begin
        Result := FArgs[I].Substring(Parameter.Length);
        break;
      end
      else
        Inc(J);
    end;
end;

function TArgParser.AsInteger(Parameter: String; Index: Integer;
  Default: Integer): Integer;
var
  I, J: Integer;
begin
  Result := Default;
  J := 0;
  for I := Low(FArgs) to High(FArgs) do
    if FArgs[I].StartsWith(Parameter, False) then
    begin
      if J >= Index then
      begin
        try
          Result := FArgs[I].Substring(Parameter.Length).ToInteger;
          break;
        except
        end;
      end
      else
        Inc(J);
    end;
end;

function TArgParser.AsFloat(Parameter: String; Index: Integer;
  Default: Single): Single;
var
  I, J: Integer;
begin
  Result := Default;
  J := 0;
  for I := Low(FArgs) to High(FArgs) do
    if FArgs[I].StartsWith(Parameter, False) then
    begin
      if J >= Index then
      begin
        try
          Result := FArgs[I].Substring(Parameter.Length).ToSingle;
          break;
        except
        end;
      end
      else
        Inc(J);
    end;
end;

function TArgParser.AsBoolean(Parameter: String; Index: Integer;
  Default: Boolean): Boolean;
var
  I, J: Integer;
begin
  Result := Default;
  J := 0;
  for I := Low(FArgs) to High(FArgs) do
    if FArgs[I].StartsWith(Parameter, False) then
    begin
      if J >= Index then
      begin
        if SameText(Parameter, FArgs[I]) then
        begin
          Result := True;
          break;
        end
        else
          try
            Result := FArgs[I].Substring(Parameter.Length).ToBoolean;
            break;
          except
          end;
      end
      else
        Inc(J);
    end;
end;

constructor TDynamicEntropy.Create(ARange: Integer);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FFirstBytes, ARange);
  FFirstBytesPos := 0;
  FEntropy := 0.00;
  FIndex := 0;
  FRange := ARange;
  FillChar(F1[0], sizeof(F1), 0);
  F1[0] := FRange;
  SetLength(F2, FRange);
  FillChar(F2[0], Length(F2), 0);
  SetLength(F3, FRange + 1);
  for I := Low(F3) to High(F3) do
  begin
    F3[I] := I / FRange;
    if I > 0 then
      F3[I] := (F3[I] * log2(F3[I]));
  end;
end;

destructor TDynamicEntropy.Destroy;
begin
  SetLength(FFirstBytes, 0);
  SetLength(F2, 0);
  SetLength(F3, 0);
  inherited Destroy;
end;

procedure TDynamicEntropy.Reset;
begin
  FFirstBytesPos := 0;
  FEntropy := 0.00;
  FIndex := 0;
  FillChar(F1[0], sizeof(F1), 0);
  F1[0] := FRange;
  FillChar(F2[0], Length(F2), 0);
end;

function TDynamicEntropy.Value: Single;
begin
  if FFirstBytesPos < FRange then
    Result := CalculateEntropy(@FFirstBytes[0], Succ(FFirstBytesPos))
  else
    Result := Abs(FEntropy);
end;

procedure TDynamicEntropy.AddByte(AByte: Byte);
begin
  if FFirstBytesPos < FRange then
  begin
    FFirstBytes[FFirstBytesPos] := AByte;
    Inc(FFirstBytesPos);
  end;
  if F2[FIndex] <> AByte then
  begin
    FEntropy := FEntropy - (F3[F1[F2[FIndex]]] - F3[Pred(F1[F2[FIndex]])]);
    Dec(F1[F2[FIndex]]);
    FEntropy := FEntropy + (F3[Succ(F1[AByte])] - F3[F1[AByte]]);
    Inc(F1[AByte]);
    F2[FIndex] := AByte;
  end;
  if Succ(FIndex) = FRange then
    FIndex := 0
  else
    Inc(FIndex);
end;

procedure TDynamicEntropy.AddData(AData: Pointer; Size: Integer);
var
  I: Integer;
begin
  for I := 0 to Size - 1 do
    AddByte((PByte(AData) + I)^);
end;

function CRC32(CRC: longword; buf: PByte; len: cardinal): longword;
begin
  Result := System.ZLib.CRC32(CRC, buf, len);
end;

function Hash32(CRC: longword; buf: PByte; len: cardinal): longword;
begin
  Result := crc32c(CRC, PAnsiChar(buf), len);
end;

procedure XORBuffer(InBuff: PByte; InSize: Integer; KeyBuff: PByte;
  KeySize: Integer);
var
  I: Integer;
begin
  Assert(Assigned(InBuff));
  Assert(Assigned(KeyBuff));
  for I := 0 to InSize - 1 do
  begin
    InBuff^ := InBuff^ xor KeyBuff^;
    Inc(InBuff);
    Inc(KeyBuff);
    if I mod KeySize = Pred(KeySize) then
      KeyBuff := KeyBuff - KeySize;
  end;
end;

function GenerateGUID: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := GUIDToString(GUID);
end;

function CalculateEntropy(Buffer: Pointer; BufferSize: Integer): Single;
var
  Entropy: Single;
  Entries: array [0 .. 255] of Integer;
  I: Integer;
  Temp: Single;
begin
  Entropy := 0.00;
  if BufferSize > 0 then
  begin
    FillChar(Entries[0], sizeof(Entries), 0);
    for I := 0 to (BufferSize - 1) do
      Inc(Entries[(PByte(Buffer) + I)^]);
    for I := Low(Entries) to High(Entries) do
    begin
      Temp := Entries[I] / BufferSize;
      if (Temp > 0) then
        Entropy := Entropy + Temp * log2(Temp);
    end;
  end;
  Result := Abs(Entropy);
end;

function CopyStream(AStream1, AStream2: TStream; ASize: Int64;
  ACallback: TFunc<Int64, Boolean>): Int64;
const
  FBufferSize = 65536;
var
  I: Integer;
  FSize: Int64;
  FBuff: array [0 .. FBufferSize - 1] of Byte;
begin
  Result := 0;
  if ASize <= 0 then
    exit;
  FSize := ASize;
  I := AStream1.Read(FBuff[0], Min(FBufferSize, FSize));
  while I > 0 do
  begin
    AStream2.WriteBuffer(FBuff[0], I);
    Dec(FSize, I);
    if Assigned(ACallback) then
      if not ACallback(ASize - FSize) then
        break;
    Result := ASize - FSize;
    I := AStream1.Read(FBuff[0], Min(FBufferSize, FSize));
  end;
end;

procedure CopyStreamEx(AStream1, AStream2: TStream; ASize: Int64;
  ACallback: TFunc<Int64, Boolean>);
const
  FBufferSize = 65536;
var
  I: Integer;
  FSize: Int64;
  FBuff: array [0 .. FBufferSize - 1] of Byte;
begin
  if ASize <= 0 then
    exit;
  FSize := ASize;
  I := Min(FBufferSize, FSize);
  AStream1.ReadBuffer(FBuff[0], I);
  while I > 0 do
  begin
    AStream2.WriteBuffer(FBuff[0], I);
    Dec(FSize, I);
    if Assigned(ACallback) then
      if not ACallback(ASize - FSize) then
        break;
    I := Min(FBufferSize, FSize);
    AStream1.ReadBuffer(FBuff[0], I);
  end;
end;

function EndianSwap(A: Single): Single;
var
  C: array [0 .. 3] of Byte absolute Result;
  d: array [0 .. 3] of Byte absolute A;
begin
  C[0] := d[3];
  C[1] := d[2];
  C[2] := d[1];
  C[3] := d[0];
end;

function EndianSwap(A: double): double;
var
  C: array [0 .. 7] of Byte absolute Result;
  d: array [0 .. 7] of Byte absolute A;
begin
  C[0] := d[7];
  C[1] := d[6];
  C[2] := d[5];
  C[3] := d[4];
  C[4] := d[3];
  C[5] := d[2];
  C[6] := d[1];
  C[7] := d[0];
end;

function EndianSwap(A: Int64): Int64;
var
  C: array [0 .. 7] of Byte absolute Result;
  d: array [0 .. 7] of Byte absolute A;
begin
  C[0] := d[7];
  C[1] := d[6];
  C[2] := d[5];
  C[3] := d[4];
  C[4] := d[3];
  C[5] := d[2];
  C[6] := d[1];
  C[7] := d[0];
end;

function EndianSwap(A: UInt64): UInt64;
var
  C: array [0 .. 7] of Byte absolute Result;
  d: array [0 .. 7] of Byte absolute A;
begin
  C[0] := d[7];
  C[1] := d[6];
  C[2] := d[5];
  C[3] := d[4];
  C[4] := d[3];
  C[5] := d[2];
  C[6] := d[1];
  C[7] := d[0];
end;

function EndianSwap(A: Int32): Int32;
var
  C: array [0 .. 3] of Byte absolute Result;
  d: array [0 .. 3] of Byte absolute A;
begin
  C[0] := d[3];
  C[1] := d[2];
  C[2] := d[1];
  C[3] := d[0];
end;

function EndianSwap(A: UInt32): UInt32;
var
  C: array [0 .. 3] of Byte absolute Result;
  d: array [0 .. 3] of Byte absolute A;
begin
  C[0] := d[3];
  C[1] := d[2];
  C[2] := d[1];
  C[3] := d[0];
end;

function EndianSwap(A: Int16): Int16;
var
  C: array [0 .. 1] of Byte absolute Result;
  d: array [0 .. 1] of Byte absolute A;
begin
  C[0] := d[1];
  C[1] := d[0];
end;

function EndianSwap(A: UInt16): UInt16;
var
  C: array [0 .. 1] of Byte absolute Result;
  d: array [0 .. 1] of Byte absolute A;
begin
  C[0] := d[1];
  C[1] := d[0];
end;

function BinarySearch(SrcMem: Pointer; SrcPos, SrcSize: NativeInt;
  SearchMem: Pointer; SearchSize: NativeInt; var ResultPos: NativeInt): Boolean;
var
  Pos: NativeInt;
begin
  Result := False;
  if (SearchSize <= 0) then
    exit;
  case SearchSize of
    sizeof(Byte):
      begin
        Pos := SrcPos;
        while Pos <= (SrcSize - SearchSize) do
        begin
          if PByte(PByte(SrcMem) + Pos)^ = PByte(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Inc(Pos);
        end;
      end;
    sizeof(Word):
      begin
        Pos := SrcPos;
        while Pos <= (SrcSize - SearchSize) do
        begin
          if PWord(PByte(SrcMem) + Pos)^ = PWord(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Inc(Pos);
        end;
      end;
    sizeof(cardinal):
      begin
        Pos := SrcPos;
        while Pos <= (SrcSize - SearchSize) do
        begin
          if PCardinal(PByte(SrcMem) + Pos)^ = PCardinal(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Inc(Pos);
        end;
      end;
    sizeof(UInt64):
      begin
        Pos := SrcPos;
        while Pos <= (SrcSize - SearchSize) do
        begin
          if PUInt64(PByte(SrcMem) + Pos)^ = PUInt64(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Inc(Pos);
        end;
      end;
  else
    Pos := SrcPos;
    while Pos <= (SrcSize - SearchSize) do
    begin
      if PWord(PByte(SrcMem) + Pos)^ = PWord(SearchMem)^ then
        if CompareMem(PByte(SrcMem) + Pos, SearchMem, SearchSize) then
        begin
          ResultPos := Pos;
          Result := True;
          break;
        end;
      Inc(Pos);
    end;
  end;
end;

function BinarySearch2(SrcMem: Pointer; SrcPos, SrcSize: NativeInt;
  SearchMem: Pointer; SearchSize: NativeInt; var ResultPos: NativeInt): Boolean;
var
  Pos: NativeInt;
begin
  Result := False;
  if (SearchSize <= 0) then
    exit;
  case SearchSize of
    sizeof(Byte):
      begin
        Pos := SrcPos - SearchSize;
        while Pos >= SrcPos do
        begin
          if PByte(PByte(SrcMem) + Pos)^ = PByte(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Dec(Pos);
        end;
      end;
    sizeof(Word):
      begin
        Pos := SrcPos - SearchSize;
        while Pos >= SrcPos do
        begin
          if PWord(PByte(SrcMem) + Pos)^ = PWord(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Dec(Pos);
        end;
      end;
    sizeof(cardinal):
      begin
        Pos := SrcPos - SearchSize;
        while Pos >= SrcPos do
        begin
          if PCardinal(PByte(SrcMem) + Pos)^ = PCardinal(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Dec(Pos);
        end;
      end;
    sizeof(UInt64):
      begin
        Pos := SrcPos - SearchSize;
        while Pos >= SrcPos do
        begin
          if PUInt64(PByte(SrcMem) + Pos)^ = PUInt64(SearchMem)^ then
          begin
            ResultPos := Pos;
            Result := True;
            break;
          end;
          Dec(Pos);
        end;
      end;
  else
    Pos := SrcPos - SearchSize;
    while Pos >= SrcPos do
    begin
      if PWord(PByte(SrcMem) + Pos)^ = PWord(SearchMem)^ then
        if CompareMem(PByte(SrcMem) + Pos, SearchMem, SearchSize) then
        begin
          ResultPos := Pos;
          Result := True;
          break;
        end;
      Dec(Pos);
    end;
  end;
end;

procedure ReverseBytes(Source, Dest: Pointer; Size: NativeInt);
begin
  Dest := PByte(NativeInt(Dest) + Size - 1);
  while (Size > 0) do
  begin
    PByte(Dest)^ := PByte(Source)^;
    Inc(PByte(Source));
    Dec(PByte(Dest));
    Dec(Size);
  end;
end;

function EncodePatch(OldBuff: Pointer; OldSize: Integer; NewBuff: Pointer;
  NewSize: Integer; PatchBuff: Pointer; PatchSize: Integer): Integer;

  function highbit64(V: UInt64): cardinal;
  var
    Count: cardinal;
  begin
    Count := 0;
    Assert(V <> 0);
    V := V shr 1;
    while V <> 0 do
    begin
      V := V shr 1;
      Inc(Count);
    end;
    Result := Count;
  end;

var
  Ctx: ZSTD_CCtx;
  Inp: ZSTD_inBuffer;
  Oup: ZSTD_outBuffer;
  Res: NativeInt;
begin
  Ctx := ZSTD_createCCtx;
  try
    Oup.dst := PatchBuff;
    Oup.Size := PatchSize;
    Oup.Pos := 0;
    Inp.src := OldBuff;
    Inp.Size := OldSize;
    Inp.Pos := 0;
    ZSTD_initCStream(Ctx, 1);
    ZSTD_CCtx_setParameter(Ctx, ZSTD_cParameter.ZSTD_c_windowLog,
      highbit64(NewSize) + 1);
    ZSTD_CCtx_setParameter(Ctx,
      ZSTD_cParameter.ZSTD_c_enableLongDistanceMatching, 1);
    ZSTD_CCtx_refPrefix(Ctx, NewBuff, NewSize);
    while Inp.Pos < Inp.Size do
    begin
      Res := ZSTD_compressStream(Ctx, Oup, Inp);
      if Res < 0 then
        exit(0)
      else
        break;
    end;
    ZSTD_flushStream(Ctx, Oup);
    ZSTD_endStream(Ctx, Oup);
    Result := Oup.Pos;
  finally
    ZSTD_freeCCtx(Ctx);
  end;
end;

function DecodePatch(PatchBuff: Pointer; PatchSize: Integer; OldBuff: Pointer;
  OldSize: Integer; NewBuff: Pointer; NewSize: Integer): Integer;
var
  Ctx: ZSTD_DCtx;
  Inp: ZSTD_inBuffer;
  Oup: ZSTD_outBuffer;
begin
  Ctx := ZSTD_createDCtx;
  try
    Oup.dst := NewBuff;
    Oup.Size := NewSize;
    Oup.Pos := 0;
    Inp.src := PatchBuff;
    Inp.Size := PatchSize;
    Inp.Pos := 0;
    ZSTD_initDStream(Ctx);
    ZSTD_DCtx_refPrefix(Ctx, OldBuff, OldSize);
    while Inp.Pos < Inp.Size do
    begin
      if ZSTD_decompressStream(Ctx, Oup, Inp) <= 0 then
        break;
    end;
    Result := Oup.Pos;
  finally
    ZSTD_freeDCtx(Ctx);
  end;
end;

function CloseValues(Value, Min, Max: Integer): TArray<Integer>;
var
  I, Init, Index: Integer;
  Up: Boolean;
begin
  SetLength(Result, Succ(Max - Min));
  if InRange(Value, Min, Max) then
    Init := Value
  else
    Init := Min + (Max - Min) div 2;
  Index := 0;
  for I := Low(Result) to High(Result) do
  begin
    Up := Odd(I);
    if Up then
      Up := Init + Index <= Max
    else
      Up := Init - Index < Min;
    if Up then
      Result[I] := Init + Index
    else
      Result[I] := Init - Index;
    if (Odd(I) = False) or (Init - Index < Min) or (Init + Index > Max) then
      Inc(Index);
  end;
end;

function CompareSize(Original, New, Current: Int64): Boolean;
begin
  Result := (Max(Original, New) - Min(Original, New)) <=
    (Max(Original, Current) - Min(Original, Current));
end;

function GetIniString(Section, Key, Default, FileName: string): string;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FileName);
  with Ini do
    try
      Result := Ini.ReadString(Section, Key, Default);
    finally
      Free;
    end;
end;

function GetIniString(Section, Key, Default: string; Ini: TMemIniFile): string;
begin
  Result := Ini.ReadString(Section, Key, Default);
end;

procedure SetIniString(Section, Key, Value, FileName: string);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FileName);
  with Ini do
    try
      Ini.WriteString(Section, Key, Value);
    finally
      Free;
    end;
end;

procedure SetIniString(Section, Key, Value: string; Ini: TMemIniFile);
begin
  Ini.WriteString(Section, Key, Value);
end;

function DecodeStr(str, Dec: string; Count: Integer): TStringDynArray;
var
  tmp, S: string;
  I: Integer;
begin
  tmp := str;
  SetLength(Result, Succ(Min(Length(tmp) - Length(ReplaceText(tmp, Dec, '')
    ), Count)));
  for I := Low(Result) to High(Result) do
  begin
    if I = High(Result) then
      Result[I] := tmp
    else
    begin
      S := Copy(tmp, 1, Pos(Dec, tmp) - 1);
      Delete(tmp, 1, Pos(Dec, tmp));
      Result[I] := S;
    end;
  end;
end;

function AnsiDecodeStr(str, Dec: Ansistring): TArray<Ansistring>;
var
  tmp, S: Ansistring;
  I: Integer;
begin
  tmp := str + Dec;
  SetLength(Result, Length(tmp) - Length(AnsiReplaceText(tmp, Dec, '')));
  for I := Low(Result) to High(Result) do
  begin
    S := Copy(tmp, 1, AnsiPos(Dec, tmp) - 1);
    Delete(tmp, 1, AnsiPos(Dec, tmp));
    Result[I] := S;
  end;
end;

function GetStr(Input: Pointer; MaxLength: Integer; var outStr: string)
  : Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to MaxLength do
  begin
    if (PByte(Input) + I - 1)^ = 0 then
      break;
    Inc(Result);
  end;
  outStr := Copy(String(PAnsiChar(Input)), 0, Result);
end;

function IndexTextA(AText: PAnsiChar;
  const AValues: array of PAnsiChar): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(AValues) to High(AValues) do
    if AnsiSameText(AText, AValues[I]) then
    begin
      Result := I;
      break;
    end;
end;

function IndexTextW(AText: PWideChar;
  const AValues: array of PWideChar): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(AValues) to High(AValues) do
    if SameText(AText, AValues[I]) then
    begin
      Result := I;
      break;
    end;
end;

function CaseStr(AIndex: Integer; const AValues: array of String): String;
begin
  Result := '';
  if AIndex in [Integer(Low(AValues)) .. Integer(High(AValues))] then
    Result := AValues[AIndex];
end;

function CaseInt(AIndex: Integer; const AValues: array of Integer): Integer;
begin
  Result := 0;
  if AIndex in [Integer(Low(AValues)) .. Integer(High(AValues))] then
    Result := AValues[AIndex];
end;

procedure Relocate(AMemory: PByte; ASize: NativeInt; AFrom, ATo: NativeInt);
const
  BuffSize = 65536;
var
  Buff: array [0 .. BuffSize - 1] of Byte;
  Pos: NativeInt;
begin
  if Max(AFrom, ATo) - Min(AFrom, ATo) >= ASize then
    Move((AMemory + AFrom)^, (AMemory + ATo)^, ASize)
  else
  begin
    Pos := 0;
    while Pos < ASize do
    begin
      Move((AMemory + AFrom + Pos)^, Buff[0], Min(BuffSize, ASize));
      Move(Buff[0], (AMemory + ATo + Pos)^, Min(BuffSize, ASize));
      Inc(Pos, BuffSize);
    end;
  end;
end;

function ConvertToBytes(S: string): Int64;
begin
  if ContainsText(S, 'kb') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 2)) * Power(1024, 1));
    exit;
  end;
  if ContainsText(S, 'mb') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 2)) * Power(1024, 2));
    exit;
  end;
  if ContainsText(S, 'gb') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 2)) * Power(1024, 3));
    exit;
  end;
  if ContainsText(S, 'k') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 1)) * Power(1024, 1));
    exit;
  end;
  if ContainsText(S, 'm') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 1)) * Power(1024, 2));
    exit;
  end;
  if ContainsText(S, 'g') then
  begin
    Result := Round(StrToFloat(Copy(S, 1, Length(S) - 1)) * Power(1024, 3));
    exit;
  end;
  Result := StrToInt64(S);
end;

function ConvertToThreads(S: string): Integer;
begin
  if ContainsText(S, 'p') or ContainsText(S, '%') then
  begin
    Result := Round((CPUCount * StrToInt(Copy(S, 1, Length(S) - 1))) / 100);
    if Result < 1 then
      Result := 1;
    exit;
  end;
  Result := StrToInt64(S);
end;

function ConvertKB2TB(Value: Int64): string;
  function NumToStr(Float: Single; DeciCount: Integer): string;
  begin
    Result := Format('%.' + IntToStr(DeciCount) + 'n', [Float]);
    Result := ReplaceStr(Result, ',', '');
  end;

const
  MV = 1024;
var
  S, MB, GB, TB: string;
begin
  MB := 'MB';
  GB := 'GB';
  TB := 'TB';
  if Value < Power(1000, 2) then
  begin
    S := NumToStr(Value / Power(MV, 1), 2);
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 1 then
      Result := NumToStr(Value / Power(MV, 1), 2) + ' ' + MB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 2 then
      Result := NumToStr(Value / Power(MV, 1), 1) + ' ' + MB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 3 then
      Result := NumToStr(Value / Power(MV, 1), 0) + ' ' + MB;
  end
  else if Value < Power(1000, 3) then
  begin
    S := NumToStr(Value / Power(MV, 2), 2);
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 1 then
      Result := NumToStr(Value / Power(MV, 2), 2) + ' ' + GB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 2 then
      Result := NumToStr(Value / Power(MV, 2), 1) + ' ' + GB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 3 then
      Result := NumToStr(Value / Power(MV, 2), 0) + ' ' + GB;
  end
  else if Value < Power(1000, 4) then
  begin
    S := NumToStr(Value / Power(MV, 3), 2);
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 1 then
      Result := NumToStr(Value / Power(MV, 3), 2) + ' ' + TB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 2 then
      Result := NumToStr(Value / Power(MV, 3), 1) + ' ' + TB;
    if Length(AnsiLeftStr(S, AnsiPos('.', S) - 1)) = 3 then
      Result := NumToStr(Value / Power(MV, 3), 0) + ' ' + TB;
  end;
end;

function BoolArray(const Bool: TArray<Boolean>; Value: Boolean): Boolean;
var
  I: Integer;
begin
  for I := Low(Bool) to High(Bool) do
  begin
    if Bool[I] <> Value then
    begin
      Result := False;
      exit;
    end;
  end;
  Result := True;
end;

function GetUsedProcessMemory(hProcess: THandle): Int64;
var
  memCounters: TProcessMemoryCounters;
  cb: DWORD;
begin
  Result := 0;
  FillChar(memCounters, sizeof(TProcessMemoryCounters), 0);
  cb := sizeof(TProcessMemoryCounters);
  memCounters.cb := cb;
  if GetProcessMemoryInfo(hProcess, @memCounters, cb) then
    Result := memCounters.WorkingSetSize;
end;

function GetFreeSystemMemory: Int64;
var
  MemoryStatus: TMemoryStatusEx;
begin
  Result := 0;
  FillChar(MemoryStatus, sizeof(TMemoryStatusEx), 0);
  MemoryStatus.dwLength := sizeof(TMemoryStatusEx);
  if GlobalMemoryStatusEx(MemoryStatus) then
    Result := MemoryStatus.ullAvailPhys;
end;

function GetUsedSystemMemory: Int64;
var
  MemoryStatus: TMemoryStatusEx;
begin
  Result := 0;
  FillChar(MemoryStatus, sizeof(TMemoryStatusEx), 0);
  MemoryStatus.dwLength := sizeof(TMemoryStatusEx);
  if GlobalMemoryStatusEx(MemoryStatus) then
    Result := MemoryStatus.ullTotalPhys - MemoryStatus.ullAvailPhys;
end;

function GetTotalSystemMemory: Int64;
var
  MemoryStatus: TMemoryStatusEx;
begin
  Result := 0;
  FillChar(MemoryStatus, sizeof(TMemoryStatusEx), 0);
  MemoryStatus.dwLength := sizeof(TMemoryStatusEx);
  if GlobalMemoryStatusEx(MemoryStatus) then
    Result := MemoryStatus.ullTotalPhys;
end;

function FileSize(const AFileName: string): Int64;
var
  AttributeData: TWin32FileAttributeData;
begin
  if GetFileAttributesEx(PChar(AFileName), GetFileExInfoStandard, @AttributeData)
  then
  begin
    Int64Rec(Result).Lo := AttributeData.nFileSizeLow;
    Int64Rec(Result).Hi := AttributeData.nFileSizeHigh;
  end
  else
    Result := 0;
end;

function GetFileList(const APath: TArray<string>; SubDir: Boolean)
  : TArray<string>;
var
  I: Integer;
  LList: TStringDynArray;
  LSO: TSearchOption;
  LPath: String;
begin
  SetLength(Result, 0);
  LSO := TSearchOption(SubDir);
  for I := Low(APath) to High(APath) do
  begin
    LPath := TPath.GetFullPath(APath[I]);
    if FileExists(LPath) then
      Insert(LPath, Result, Length(Result))
    else if DirectoryExists(LPath) then
    begin
      LList := TDirectory.GetFiles(LPath, '*', LSO);
      Insert(LList, Result, Length(Result));
    end
    else if Pos('*', LPath) > 0 then
    begin
      LList := TDirectory.GetFiles(IfThen(ExtractFileDir(LPath) = '',
        GetCurrentDir, ExtractFilePath(LPath)), ExtractFileName(LPath), LSO);
      Insert(LList, Result, Length(Result));
    end;
  end;
  SetLength(LList, 0);
end;

procedure FileReadBuffer(Handle: THandle; var Buffer; Count: NativeInt);
var
  LTotalCount, LReadCount: NativeInt;
begin
  LTotalCount := FileRead(Handle, Buffer, Count);
  if LTotalCount < 0 then
    raise EReadError.CreateRes(@SReadError);
  while (LTotalCount < Count) do
  begin
    LReadCount := FileRead(Handle, (PByte(@Buffer) + LTotalCount)^,
      (Count - LTotalCount));
    if LReadCount <= 0 then
      raise EReadError.CreateRes(@SReadError)
    else
      Inc(LTotalCount, LReadCount);
  end
end;

procedure FileWriteBuffer(Handle: THandle; const Buffer; Count: NativeInt);
var
  LTotalCount, LWrittenCount: NativeInt;
begin
  LTotalCount := FileWrite(Handle, Buffer, Count);
  if LTotalCount < 0 then
    raise EWriteError.CreateRes(@SWriteError);
  while (LTotalCount < Count) do
  begin
    LWrittenCount := FileWrite(Handle, (PByte(@Buffer) + LTotalCount)^,
      (Count - LTotalCount));
    if LWrittenCount <= 0 then
      raise EWriteError.CreateRes(@SWriteError)
    else
      Inc(LTotalCount, LWrittenCount);
  end
end;

procedure CloseHandleEx(var Handle: THandle);
var
  lpdwFlags: DWORD;
begin
  if Handle = 0 then
    exit;
  if GetHandleInformation(Handle, lpdwFlags) then
    if lpdwFlags <> HANDLE_FLAG_PROTECT_FROM_CLOSE then
    begin
      CloseHandle(Handle);
      Handle := 0;
    end;
end;

function ExpandPath(const AFileName: string; AFullPath: Boolean): String;
begin
  if AFileName = '' then
    Result := ''
  else if Pos(':', AFileName) > 0 then
    Result := AFileName
  else
    Result := ExtractFilePath(GetModuleName) + AFileName;
  if AFullPath then
    Result := TPath.GetFullPath(Result);
end;

function Exec(Executable, CommandLine, WorkDir: string): Boolean;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  LWorkDir: PChar;
begin
  Result := False;
  FillChar(StartupInfo, sizeof(StartupInfo), #0);
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := 0;
  StartupInfo.hStdOutput := 0;
  StartupInfo.hStdError := 0;
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    False, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    Result := dwExitCode = 0;
  end
  else
    RaiseLastOSError;
end;

function ExecStdin(Executable, CommandLine, WorkDir: string; InBuff: Pointer;
  InSize: Integer): Boolean;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
var
  hstdinr, hstdinw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  LWorkDir: PChar;
begin
  Result := False;
  CreatePipe(hstdinr, hstdinw, @PipeSecurityAttributes, 0);
  SetHandleInformation(hstdinw, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := hstdinr;
  StartupInfo.hStdOutput := 0;
  StartupInfo.hStdError := 0;
  ZeroMemory(@ProcessInfo, sizeof(ProcessInfo));
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    True, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    CloseHandleEx(hstdinr);
    try
      FileWriteBuffer(hstdinw, InBuff^, InSize);
    finally
      CloseHandleEx(hstdinw);
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    Result := dwExitCode = 0;
  end
  else
  begin
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdinw);
    RaiseLastOSError;
  end;
end;

function ExecStdin(Executable, CommandLine, WorkDir: string; InStream: TStream)
  : Boolean overload;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
  LBufferSize = 65536;
var
  hstdinr, hstdinw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  LWorkDir: PChar;
  LReadBytes: Integer;
  LBuffer: array [0 .. LBufferSize - 1] of Byte;
begin
  Result := False;
  CreatePipe(hstdinr, hstdinw, @PipeSecurityAttributes, 0);
  SetHandleInformation(hstdinw, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := hstdinr;
  StartupInfo.hStdOutput := 0;
  StartupInfo.hStdError := 0;
  ZeroMemory(@ProcessInfo, sizeof(ProcessInfo));
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    True, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    CloseHandleEx(hstdinr);
    try
      LReadBytes := InStream.Read(LBuffer[0], LBufferSize);
      while LReadBytes > 0 do
      begin
        FileWriteBuffer(hstdinw, LBuffer[0], LReadBytes);
        LReadBytes := InStream.Read(LBuffer[0], LBufferSize);
      end;
    finally
      CloseHandleEx(hstdinw);
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    Result := dwExitCode = 0;
  end
  else
  begin
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdinw);
    RaiseLastOSError;
  end;
end;

function ExecStdout(Executable, CommandLine, WorkDir: string;
  Output: TExecOutput): Boolean;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
  LBufferSize = 65536;
var
  hstdoutr, hstdoutw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  BytesRead: DWORD;
  LWorkDir: PChar;
  LBuffer: array [0 .. LBufferSize - 1] of Byte;
begin
  Result := False;
  CreatePipe(hstdoutr, hstdoutw, @PipeSecurityAttributes, 0);
  SetHandleInformation(hstdoutr, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := 0;
  StartupInfo.hStdOutput := hstdoutw;
  StartupInfo.hStdError := 0;
  ZeroMemory(@ProcessInfo, sizeof(ProcessInfo));
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    True, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    CloseHandleEx(hstdoutw);
    try
      while ReadFile(hstdoutr, LBuffer, LBufferSize, BytesRead, nil) and
        (BytesRead > 0) do
        Output(@LBuffer[0], BytesRead);
    finally
      CloseHandleEx(hstdoutr);
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    Result := dwExitCode = 0;
  end
  else
  begin
    CloseHandleEx(hstdoutr);
    CloseHandleEx(hstdoutw);
    RaiseLastOSError;
  end;
end;

procedure ExecReadTask(Handle, Stream, Done: IntPtr);
const
  LBufferSize = 65536;
var
  LBuffer: array [0 .. LBufferSize - 1] of Byte;
  BytesRead: DWORD;
begin
  PBoolean(Pointer(Done))^ := False;
  while ReadFile(Handle, LBuffer[0], LBufferSize, BytesRead, nil) and
    (BytesRead > 0) do
    PExecOutput(Pointer(Stream))^(@LBuffer[0], BytesRead);
  PBoolean(Pointer(Done))^ := BytesRead = 0;
end;

function ExecStdio(Executable, CommandLine, WorkDir: string; InBuff: Pointer;
  InSize: Integer; Output: TExecOutput): Boolean;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
var
  hstdinr, hstdinw: THandle;
  hstdoutr, hstdoutw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  LWorkDir: PChar;
  LTask: TTask;
  LDone: Boolean;
begin
  Result := False;
  CreatePipe(hstdinr, hstdinw, @PipeSecurityAttributes, 0);
  CreatePipe(hstdoutr, hstdoutw, @PipeSecurityAttributes, 0);
  SetHandleInformation(hstdinw, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(hstdoutr, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := hstdinr;
  StartupInfo.hStdOutput := hstdoutw;
  StartupInfo.hStdError := 0;
  ZeroMemory(@ProcessInfo, sizeof(ProcessInfo));
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    True, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdoutw);
    LTask := TTask.Create(hstdoutr, NativeInt(@Output), NativeInt(@LDone));
    LTask.Perform(ExecReadTask);
    LTask.Start;
    try
      FileWriteBuffer(hstdinw, InBuff^, InSize);
    finally
      CloseHandleEx(hstdinw);
      LTask.Wait;
      if LTask.Status <> TThreadStatus.tsErrored then
      begin
        LTask.Free;
        LTask := nil;
      end;
      CloseHandleEx(hstdoutr);
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    if Assigned(LTask) then
      if LTask.Status <> TThreadStatus.tsErrored then
        try
          LTask.RaiseLastError;
        finally
          LTask.Free;
        end;
    Result := dwExitCode = 0;
  end
  else
  begin
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdinw);
    CloseHandleEx(hstdoutr);
    CloseHandleEx(hstdoutw);
    RaiseLastOSError;
  end;
end;

function ExecStdio(Executable, CommandLine, WorkDir: string; InStream: TStream;
  Output: TExecOutput): Boolean;
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
  LBufferSize = 65536;
var
  hstdinr, hstdinw: THandle;
  hstdoutr, hstdoutw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  dwExitCode: DWORD;
  LWorkDir: PChar;
  LReadBytes: Integer;
  LBuffer: array [0 .. LBufferSize - 1] of Byte;
  LTask: TTask;
  LDone: Boolean;
begin
  Result := False;
  CreatePipe(hstdinr, hstdinw, @PipeSecurityAttributes, 0);
  CreatePipe(hstdoutr, hstdoutw, @PipeSecurityAttributes, 0);
  SetHandleInformation(hstdinw, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(hstdoutr, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@StartupInfo, sizeof(StartupInfo));
  StartupInfo.cb := sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := hstdinr;
  StartupInfo.hStdOutput := hstdoutw;
  StartupInfo.hStdError := 0;
  ZeroMemory(@ProcessInfo, sizeof(ProcessInfo));
  if WorkDir <> '' then
    LWorkDir := Pointer(WorkDir)
  else
    LWorkDir := Pointer(GetCurrentDir);
  if CreateProcess(nil, PChar('"' + Executable + '" ' + CommandLine), nil, nil,
    True, 0, nil, LWorkDir, StartupInfo, ProcessInfo) then
  begin
    CloseHandleEx(ProcessInfo.hThread);
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdoutw);
    LTask := TTask.Create(hstdoutr, NativeInt(@Output), NativeInt(@LDone));
    LTask.Perform(ExecReadTask);
    LTask.Start;
    try
      LReadBytes := InStream.Read(LBuffer[0], LBufferSize);
      while LReadBytes > 0 do
      begin
        FileWriteBuffer(hstdinw, LBuffer[0], LReadBytes);
        LReadBytes := InStream.Read(LBuffer[0], LBufferSize);
      end;
    finally
      CloseHandleEx(hstdinw);
      LTask.Wait;
      if LTask.Status <> TThreadStatus.tsErrored then
      begin
        LTask.Free;
        LTask := nil;
      end;
      CloseHandleEx(hstdoutr);
    end;
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, dwExitCode);
    CloseHandleEx(ProcessInfo.hProcess);
    if Assigned(LTask) then
      if LTask.Status <> TThreadStatus.tsErrored then
        try
          LTask.RaiseLastError;
        finally
          LTask.Free;
        end;
    Result := dwExitCode = 0;
  end
  else
  begin
    CloseHandleEx(hstdinr);
    CloseHandleEx(hstdinw);
    CloseHandleEx(hstdoutr);
    CloseHandleEx(hstdoutw);
    RaiseLastOSError;
  end;
end;

function GetCmdStr(CommandLine: String; Index: Integer;
  KeepQuotes: Boolean): string;
var
  I, J, Idx: Integer;
  Quoted: Boolean;
begin
  Result := '';
  Quoted := False;
  Idx := 0;
  I := 1;
  while Idx <= Index do
  begin
    Quoted := False;
    while (I <= CommandLine.Length) and
      ((CommandLine[I] = ' ') or (CommandLine[I] = #09)) do
      Inc(I);
    if I > CommandLine.Length then
      break;
    Quoted := CommandLine[I] = '"';
    J := Succ(I);
    if Quoted then
      Inc(I);
    if Quoted then
    begin
      while (J <= CommandLine.Length) and (CommandLine[J] <> '"') do
        Inc(J);
    end
    else
    begin
      while (J <= CommandLine.Length) and
        (not(CharInSet(CommandLine[J], [' ', '"']))) do
        Inc(J);
    end;
    if Idx = Index then
      if (CommandLine[I] = '"') and (CommandLine[I] = CommandLine[Succ(I)]) then
        Result := ''
      else
        Result := CommandLine.Substring(Pred(I), J - I);
    if (Quoted = False) and (CommandLine[J] = '"') then
      I := J
    else
      I := Succ(J);
    Inc(Idx);
  end;
  if KeepQuotes and Quoted then
    Result := '"' + Result + '"';
end;

function GetCmdCount(CommandLine: String): Integer;
begin
  Result := 0;
  while GetCmdStr(CommandLine, Result, True) <> '' do
    Inc(Result);
end;

end.
