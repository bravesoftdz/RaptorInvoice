  unit hextext;

  interface

  { Dependancies }
  Uses sysutils, classes, contnrs, hexbase;

  { Constants for THEXTextDivider exceptions }
  Const
  ERR_HEX_DelimiterIsNull         = 'Delimiter character cannot be null error';
  ERR_HEX_StringIndexOutOfBounds  = 'String index out of bounds error: %d';

  Type

  { Exceptions for THEXTextDivider}
  EHEXTextDivider                 = Class(EHEXException);
  EHEXDelimiterIsNull             = Class(EHEXTextDivider);
  EHEXStringIndexOutOfBounds      = Class(EHEXTextDivider);

  IHexTextElement = Interface
    ['{C185F0CE-BE0E-4ADA-8697-F227D38BB683}']
    Procedure SetText(Value:String);
    Procedure SetTextPos(Value:Integer);
  End;

  { Text element object. Represents one word in a phrase }
  THEXTextElement = Class(TInterfacedObject,IHexTextElement)
  Private
    FText:      String;
    FPosition:  Integer;
  protected
    Procedure   SetText(Value:String);virtual;
    Procedure   SetTextPos(Value:Integer);virtual;
  Published
    Property    Value:String read FText;
    Property    Position:Integer read FPosition;
  End;

  { Text elements collection. Represents a string of words }
  THEXTextElements = Class(TObject)
  Private
    FObjects:   TObjectList;
    Function    GetItem(Index:Integer):THEXTextElement;
    Function    GetCount:Integer;
  Protected
    Function    AddElement(AText:String;APosition:Integer):THEXTextElement;
  Public
    Property    Items[index:Integer]:THEXTextElement read GetItem;default;
    Property    Count:Integer read GetCount;
    Procedure   Delete(Index:Integer);overload;
    Procedure   Delete(Item:THEXTextElement);overload;
    Function    IndexOf(Value:String):Integer;
    Function    ObjectOf(Value:String):THEXTextElement;
    Procedure   Clear;
    Constructor Create;
    Destructor  Destroy;override;
  End;

  { Actual text divider class }
  THEXTextDivider = Class(THEXCustomWorkComponent)
  Private
    FText:        String;
    FObjects:     THexTextElements;
    FDelimiter:   Char;
    Function      QuickSeekChar(Var FBuffer:PCHAR;Const Position: Integer):Integer;
    Function      QuickNextWord(Var FBuffer: PChar;Const Delimiter:Char;Const Position:Integer):Integer;
    Procedure     DelimitTextBuffer;
  Public
    Property      Text: String read FText write FText;
    Property      Elements:THEXTextElements read FObjects;
    Procedure     LoadFromFile(Const Filename:String);
    Procedure     SaveToFile(Const Filename:String);
    Procedure     LoadFromStream(Stream:TStream;Length:Integer);
    Procedure     SaveToStream(Stream:TStream);
    Procedure     Clear;
    Procedure     ParseText;overload;
    Procedure     ParseText(Text:String);overload;
    Constructor   Create(AOwner: TComponent);Override;
    Destructor    Destroy;Override;
  Published
    Property      EventFlags;
    Property      Delimiter: Char read FDelimiter write FDelimiter;
    Property      OnWorkBegins;
    Property      OnWorkComplete;
    Property      OnWorkProgress;
    Property      OnEventFlagsChanged;
    Property      OnDataCleared;
  End;

  implementation

  { standard charset }
  var
  _SeekCharset: String;

  //###############################################################
  // Helper Functions
  //###############################################################

  Function HEXTraverseText(Var FBuffer: PChar;Const Delimiter:Char;Const Position:Integer):Integer;
  Var
    Xpos: Integer;
    SMax: Integer;
  Begin
    Result:=0;
    SMax:=Length(FBuffer);

    If (Position<1) or (position>SMax) then
    begin
      raise EHEXStringIndexOutOfBounds.CreateFmt(Err_HEX_StringIndexOutOfBounds,[position]);
      exit;
    end;

    XPos:=Position;

    If xpos>0 then
    Dec(Xpos);

    while (Xpos<SMax) do
    begin
      Inc(Xpos);
      If FBuffer[xpos]=Delimiter then
      begin
        Result:=Xpos;
        Break;
      end;
    end;
  End;

  //###############################################################
  // THEXTextDivider
  //###############################################################

  Constructor THEXTextDivider.Create(AOwner: TComponent);
  Begin
    inherited Create(AOwner);
    FObjects:=THEXTextElements.Create;
    FDelimiter:=#32;
  End;

  Destructor THEXTextDivider.Destroy;
  Begin
    FObjects.free;
    inherited;
  End;

  Procedure THEXTextDivider.Clear;
  Begin
    FText:='';
    FObjects.Clear;
    DataCleared;
  End;

  Procedure THEXTextDivider.ParseText(Text:String);
  Begin
    { Flush old data }
    FObjects.Clear;

    { Keep new data }
    FText:=Text;

    { Process the data }
    try
      { Update progress report }
      WorkBegins(length(Text));

      try
        DelimitTextBuffer;
      except
        on exception do
        Begin
          Raise;
          exit;
        end;
      end;

    finally
      { Finalize progress }
      WorkComplete;
    end;
  End;

  Procedure THEXTextDivider.ParseText;
  Begin
    { Flush old data }
    FObjects.Clear;

    { Process current content }
    try
      { Update progress report }
      WorkBegins(length(FText));

      try
        DelimitTextBuffer;
      except
        on e: exception do
        Raise EHexTextDivider.Create(ExceptFormat('ParseText()',e.message));
      end;
    finally
      WorkComplete;
    end;
  End;

  Procedure THEXTextDivider.LoadFromFile(Const Filename:String);
  var
    FBuffer:  TStringList;
  Begin
    FBuffer:=TStringList.Create;
    try
      { Attempt to load the data }
      try
        FBuffer.LoadFromFile(Filename);
      except
        on e: exception do
        Begin
          Raise EHEXFailedLoadData.CreateFmt(ERR_HEX_FailedLoadData,[Filename]);
          exit;
        end;
      end;

      { Data loaded ok, keep the text }
      FText:=Text;
    finally
      { release immediate buffer }
      FBuffer.free;
    end;
  End;

  Procedure THEXTextDivider.SaveToFile(Const Filename:String);
  var
    FBuffer:  TStringList;
  Begin
    FBuffer:=TStringList.Create;
    try
      { transfere our data to stringlist }
      FBuffer.text:=FText;

      { Attempt to save the data }
      try
        FBuffer.SaveToFile(Filename);
      except
        on e: exception do
        Begin
          Raise EHEXFailedSaveData.CreateFmt(ERR_HEX_FailedSaveData,[filename]);
          exit;
        end;
      end;
    finally
      { release immediate buffer }
      FBuffer.free;
    end;
  End;

  Procedure THEXTextDivider.LoadFromStream(Stream:TStream;Length:Integer);
  var
    FTarget:  Pointer;
  Begin
    { Check that we can do this }
    if not assigned(Stream) then
    begin
      raise EHEXStreamParamIsNIL.Create(ERR_HEX_StreamParamIsNIL);
      exit;
    end;

    { Flush current data }
    Clear;

    { Resize our text buffer }
    SetLength(FText,Length);

    { Get a handle on our data }
    FTarget:=@FText[1];

    { Read in the data from the stream }
    try
      Stream.ReadBuffer(FTarget^,Length);
    except
      on e: exception do
      Raise EHEXFailedLoadDataStream.CreateFmt(ERR_HEX_FailedLoadDataStream,[e.message]);
    end;
  End;

  Procedure THEXTextDivider.SaveToStream(Stream:TStream);
  var
    FSource:  Pointer;
  Begin

    { Check that stream is valid }
    if not assigned(Stream) then
    begin
      raise EHexStreamParamIsNIL.Create(ERR_Hex_StreamParamIsNIL);
      exit;
    End;

    { No data? Just exit }
    If Length(FText)=0 then
    exit;

    { Get a pointer to our data }
    FSource:=@FText[1];

    { Write our data to the stream }
    try
      Stream.WriteBuffer(FSource^,Length(FText));
    except
      on e: exception do
      Raise EHEXFailedSaveDataStream.CreateFmt(ERR_HEX_FailedSaveDataStream,[e.message]);
    end;
  End;

  Procedure THEXTextDivider.DelimitTextBuffer;
  var
    Xpos:     Integer;
    AWork:    Integer;
    AText:    String;
    PBuffer:  PChar;

    Procedure AddWord(WordData:String;Position:Integer);
    Begin
      try
        FObjects.AddElement(WordData,Position);
      except
        on exception do
        Begin
          Raise;
          exit;
        end;
      end;
      { Update progress report }
      WorkProgress(Length(FText),Position);
    End;

  Begin
    { Reset work variables }
    Atext:='';
    Awork:=0;

    { Get a handle on our data }
    PBuffer:=PChar(FText);

    { No data to process? Just exit }
    If Length(FText)=0 then
    exit;

    { Check that delimiter is valid }
    if (FDelimiter=#0) then
    begin
      Raise EHEXDelimiterIsNull.Create(ERR_HEX_DelimiterIsNull);
      exit;
    end;

    {Get the start of the first word}
    Xpos:=QuickSeekChar(PBuffer,1);

    { Required for 1 character strings.. }
    if xpos=0 then
    begin
      If Length(FText)>0 then
      begin
      	try
          AddWord(FText,1);
        except
          raise;
          exit;
        end;
      end;
      exit;
    end else
    if xpos>1 then
    inc(xpos);

    While (Xpos<Length(FText)) do
    begin
      { Find End of Word }
      AWork:=HEXTraverseText(PBuffer,FDelimiter,XPos);  //find end of word..
      if Awork=0 then
      Break;

      AText:=Copy(FText,xpos,(Awork-xpos)+1);

      try
        AddWord(AText,xpos);
      except
        On exception do
        Begin
          raise;
          break;
        end;
      end;

      Xpos:=AWork;
      AWork:=QuickNextWord(PBuffer,FDelimiter,Xpos);
      if (Awork=0) then
      break;
      Xpos:=Awork;
      inc(Xpos);
    end;

    if (xpos>0) and (Awork=0) then
    begin
      Atext:=Copy(FText,xpos,Length(FText));
      if length(AText)>0 then
      begin
				try
          AddWord(AText,xpos);
        except
          on exception do
          Raise;
        end;
      end;
    end;
  End;

  { Locates first valid (not #32) character in a string.
    Uses _SeekCharset for validation }
  Function THEXTextDivider.QuickSeekChar(Var FBuffer:PCHAR;Const Position: Integer):Integer;
  var
    Xpos:   Integer;
    SMax:   Integer;
    FChar:  String;
  Begin
    result  :=0;
    SMax    :=Length(FBuffer);

    { Empty string? just exit }
    If SMAX=0 then
    exit;

    If (Position<1) or (position>SMax) then
    begin
      raise EHEXStringIndexOutOfBounds.CreateFmt(Err_HEX_StringIndexOutOfBounds,[IntToStr(Position)]);
      exit;
    end;

    for Xpos:=Position to SMax do
    begin
      FChar:=Copy(FBuffer,xpos,1);
      if pos(FChar,_SeekCharset)>0 then
      begin
        Result:=Xpos;
        Break;
      end;
    end;
  End;

  Function THEXTextDivider.QuickNextWord(Var FBuffer: PChar;Const Delimiter:Char;Const Position:Integer):Integer;
  Var
    Xpos: Integer;
    SMax: Integer;
  begin
    Result  :=0;
    SMax    :=Length(FBuffer);

    { Are we outside the bounds of the string? }
    if (Position<1) or (Position>SMax)then
    begin
      raise EHEXStringIndexOutOfBounds.CreateFmt(Err_HEX_StringIndexOutOfBounds,[IntToSTr(position)]);
      exit;
    end;

    For XPos:=Position to SMax do
    begin
      If FBuffer[XPos]<>Delimiter then
      begin
        Result:=Xpos;
        Break;
      end;
    end;
  End;

  //###############################################################
  // THEXTextElement
  //###############################################################

  Procedure THEXTextElement.SetText(Value:String);
  Begin
    FText:=Value;
  end;

  Procedure THEXTextElement.SetTextPos(Value:Integer);
  Begin
    FPosition:=Value;
  end;

  //###############################################################
  // THEXTextElements
  //###############################################################

  Constructor THEXTextElements.Create;
  Begin
    inherited;
    FObjects:=TObjectList.Create(True);
  End;

  Destructor THEXTextElements.Destroy;
  Begin
    FObjects.free;
    inherited;
  End;

  Procedure THEXTextElements.Clear;
  Begin
    FObjects.Clear;
  End;

  Function THEXTextElements.IndexOf(Value:String):Integer;
  var
    x:  Integer;
  Begin
    result:=-1;
    for x:=1 to FObjects.Count do
    begin
      If Items[x-1].Value=Value then
      begin
        result:=(x-1);
        Break;
      end;
    end;
  End;

  Function THEXTextElements.ObjectOf(Value:String):THEXTextElement;
  var
    x:  Integer;
  Begin
    result:=NIL;
    for x:=1 to FObjects.Count do
    begin
      If Items[x-1].Value=Value then
      begin
        result:=Items[x-1];
        Break;
      end;
    end;
  End;

  Function THEXTextElements.GetItem(Index:Integer):THEXTextElement;
  Begin
    result:=THEXTextElement(FObjects[index]);
  End;

  Function THEXTextElements.GetCount:Integer;
  Begin
    result:=FObjects.Count;
  End;

  Procedure THEXTextElements.Delete(Index:Integer);
  Begin
    try
      Delete(THEXTextElement(FObjects[index]));
    except
      on e: exception do
      Raise EHEXFailedDeleteElement.CreateFmt(ERR_HEX_FailedDeleteElement,[e.message]);
    end;
  End;

  Procedure THEXTextElements.Delete(Item:THEXTextElement);
  Begin
    If (Item=NIL) then
    Begin
      Raise EHEXParameterIsNIL.CreateFmt(ERR_HEX_ParameterIsNIL,['THEXTextElement']);
      exit;
    end;

    try
      FObjects.Delete(FObjects.IndexOf(Item));
    except
      on e: exception do
      Raise EHEXFailedDeleteElement.CreateFmt(ERR_HEX_FailedDeleteElement,[e.message]);
    end;
  End;

  Function THEXTextElements.AddElement(AText:String;APosition:Integer):THEXTextElement;
  Begin
    { Create a new text element }
    try
      Result:=THEXTextElement.Create;
    except
      on e: exception do
      Begin
        result:=NIL;
        raise EHEXFailedCreateElement.CreateFmt(ERR_HEX_FailedCreateElement,[e.message]);
        exit;
      end;
    end;

    { add element to collection }
    try
      FObjects.Add(Result);
    except
      on e: exception do
      Begin
        FreeAndNIL(Result);
        raise EHEXFailedAddElement.CreateFmt(ERR_HEX_FailedAddElement,[e.message]);
        exit;
      end;
    end;

    { Populate data }
    IHexTextElement(Result).SetText(AText);
    IHexTextElement(result).SetTextPos(APosition);
  end;

  Initialization
  Begin
    { Define charset used when parsing }
    _SeekCharset:='abcdefghijklmnopqrstuvwxyz���';
    _SeekCharset:=_SeekCharset+Uppercase(_SeekCharset);
    _SeekCharset:=_SeekCharset+':.,;-_^~*1234567890!�"#�%&()=?\|/{}[]<>�$�@`�';
  End;

  Finalization
  Begin
    { flush charset }
    _SeekCharset:='';
  End;

  end.
