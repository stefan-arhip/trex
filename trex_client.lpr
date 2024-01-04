program trex_client;

{$mode objfpc}{$H+}

uses
  sSockets,
  Classes,
  FileUtil,
  StrUtils,
  SysUtils,
  Process,
  MD5;

const
  BUFSIZE = 8192;

  cmdUpdate = 0;
  cmdRetrieveDirectory = 1;
  cmdRetrieveFilelist = 2;
  cmdSendFiles = 3;
  cmdDeleteFiles = 4;
  cmdCreateDirectory = 5;
  cmdRenameDirectory = 6;
  cmdSizeDirectory = 7;
  cmdChecksumFiles = 8;

  intOperationError = 0;
  intOperationOk = 1;

var
  strIP, strDirectory, strExeChecksum: string;
  intPort: integer;

type
  TINetServerApp = class(TObject)
  private
    BytesReceived: integer;
    FServer: TInetServer;
  public
    constructor Create(Port: longint);
    destructor Destroy; override;
    procedure OnConnect(Sender: TObject; Data: TSocketStream);
    procedure Run;
  end;

  function RunCmd(strExe: string; strParams: array of string): boolean; overload;
    //const
    //  READ_BYTES = 2048;
  var
    //MemStream: TMemoryStream;
    OurProcess: Process.TProcess;
    //  NumBytes: longint;
    //  BytesRead: longint;
    i: integer;
  begin
    //MemStream := TMemoryStream.Create;
    //BytesRead := 0;

    OurProcess := TProcess.Create(nil);
    //OurProcess.CurrentDirectory:= WorkingDirectory;
    OurProcess.Executable := strExe;
    for i := Low(strParams) to High(strParams) do
      OurProcess.Parameters.Add(strParams[i]);

    OurProcess.ShowWindow := swoHide;
    //OurProcess.ShowWindow:= swoShow;
    //OurProcess.Options := [poUsePipes];
    OurProcess.Options := [poNewConsole];
    OurProcess.Execute;
    //writeln(strExe, ' > ', strParams);
    //ShowMessage('1');
    //while True do
    //begin
    //  MemStream.SetSize(BytesRead + READ_BYTES);
    //  NumBytes := OurProcess.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
    //  if NumBytes > 0 then
    //    Inc(BytesRead, NumBytes)
    //  else
    //    Break;
    //end;
    //MemStream.SetSize(BytesRead);
    //OurResult.LoadFromStream(MemStream);
    //MemStream.Free;
    OurProcess.Free;
    //Result := OurResult.Count > 0;
    Result := True;
  end;

  function RunCmd(Cmd: string; var OurResult: TStringList): boolean; overload;
  const
    READ_BYTES = 2048;
  var
    MemStream: TMemoryStream;
    OurProcess: Process.TProcess;
    NumBytes: longint;
    BytesRead: longint;
  begin

    MemStream := TMemoryStream.Create;
    BytesRead := 0;

    OurProcess := TProcess.Create(nil);
    //OurProcess.CurrentDirectory:= WorkingDirectory;
    OurProcess.Executable := 'cmd.exe';
    OurProcess.Parameters.Add('/c');
    OurProcess.Parameters.Add(Cmd);

    OurProcess.ShowWindow := swoHide;
    //OurProcess.ShowWindow:= swoShow;
    OurProcess.Options := [poUsePipes];
    OurProcess.Execute;
    //ShowMessage('1');
    while True do
    begin
      MemStream.SetSize(BytesRead + READ_BYTES);
      NumBytes := OurProcess.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
      if NumBytes > 0 then
        Inc(BytesRead, NumBytes)
      else
        Break;
    end;
    MemStream.SetSize(BytesRead);
    OurResult.LoadFromStream(MemStream);
    MemStream.Free;
    OurProcess.Free;
    Result := OurResult.Count > 0;
  end;

  function RunCmd(Cmd: string): boolean; overload;
  var
    sLDummy: TStringList;
  begin
    sLDummy := TStringList.Create;
    Result := RunCmd(Cmd, sLDummy);
    sLDummy.Free;
  end;

  function DirectorySize(strDirectory: string; bIncludeSubDir: boolean): int64;
  var
    rec: TSearchRec;
    found: integer;
  begin
    Result := 0;
    if strDirectory[Length(strDirectory)] <> '\' then
      strDirectory := strDirectory + '\';
    found := FindFirst(strDirectory + '*.*', faAnyFile, rec);
    while found = 0 do
    begin
      Inc(Result, rec.Size);
      if (rec.Attr and faDirectory > 0) and (rec.Name[1] <> '.') and
        (bIncludeSubDir = True) then
        Inc(Result, DirectorySize(strDirectory + rec.Name, True));
      found := FindNext(rec);
    end;
    SysUtils.FindClose(rec);
  end;

  constructor TInetServerApp.Create(Port: longint);
  begin
    BytesReceived := 0;
    FServer := TINetServer.Create(Port);
    FServer.OnConnect := @OnConnect;
  end;

  destructor TInetServerApp.Destroy;
  begin
    FServer.Free;
  end;

  procedure TInetServerApp.OnConnect(Sender: TObject; Data: TSocketStream);
  var
    strChecksum, strFolder, strFileName, strCheck, strFileDate,
    strCmdUpdate, strItemOld, strItemNew, strDirectoryNew, strParameters: string;
    FileStream: TFileStream;
    Buffer: array[0..BUFSIZE - 1] of byte;
    intCmd, intOperationCode: byte;
    i: integer;
    intFileSize, recFileSize, intFileCount, intFileDate: int64;
    sR: TSearchRec;
    sLFiles: TStringList;
    dtFileDate: TDateTime;
    boolUpdateOk, boolSaveFileOk: boolean;
    arrFiles: array of string;
  begin
    strParameters := '';
    for i := 1 to ParamCount + 1 do
      strParameters := strParameters + ' ' + ParamStr(i - 1);
    //writeln('PARAMETRI:');
    //writeln(strParameters);
    try
      intCmd := Data.ReadByte;
    except
      BytesReceived := 0;
    end;
    case intCmd of
      cmdUpdate:
      begin
        intFileCount := Data.ReadDWord;
        SetLength(arrFiles, intFileCount);
        strDirectory := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)));
        strCmdUpdate := Data.ReadAnsiString;
        boolUpdateOk := True;
        for i := 1 to intFileCount do
        begin
          intFileSize := Data.ReadDWord;
          strChecksum := Data.ReadAnsiString;
          //writeln(strChecksum);
          arrFiles[i - 1] := Data.ReadAnsiString;
          arrFiles[i - 1] := strDirectory + arrFiles[i - 1];

          WriteLn('Update ', i, '/', intFileCount, ' = ', arrFiles[i - 1]);
          ForceDirectories(ExtractFileDir(arrFiles[i - 1]));
          FileStream := TFileStream.Create(arrFiles[i - 1], fmCreate);
          Initialize(Buffer, Length(Buffer));
          try
            recFileSize := 0;
            repeat
              BytesReceived := Data.Read(Buffer, BUFSIZE);
              FileStream.WriteBuffer(Buffer, BytesReceived);
              Inc(recFileSize, BytesReceived);
            until recFileSize >= intFileSize;
            FileStream.Free;
            strCheck := MD5Print(MD5File(shortstring(arrFiles[i - 1])));
            boolUpdateOk := boolUpdateOk and (strCheck = strChecksum);
            //writeln(strCheck);
            //writeln(strChecksum);
            Data.WriteAnsiString(strCheck);
            BytesReceived := 0;
          except
            boolUpdateOk := False;
            WriteLn('error');
          end;
        end;

        if boolUpdateOk then
        begin
          Data.WriteByte(intOperationOk);
          Data.Free;
          Writeln(arrFiles[0] + ' ' + arrFiles[1] + strParameters);
          //RunCmd(arrFiles[0] + ' ' + arrFiles[1] + strParameters);
          //Writeln('>>>>>>>>>>>' + strParameters);
          Writeln('>>>>>>>>>>> ' + 'C:\TEMP\trex_client_new.exe' + ' 1212 C:\TEMP\');
          //ExecuteProcess('C:\TEMP\trex_client_new.exe', ['1212', 'C:\TEMP\']);
          ExecuteProcess(arrFiles[0], []);
          //RunCmd('C:\TEMP\trex_client_new.exe', ['1212', 'C:\TEMP\']);
          Halt;
        end
        else
          Data.WriteByte(intOperationError);
      end;
      cmdRetrieveDirectory:
        Data.WriteAnsiString(strDirectory);
      cmdRetrieveFilelist:
      begin
        strFolder := Data.ReadAnsiString;
        strFolder := IncludeTrailingPathDelimiter(strFolder);

        sLFiles := TStringList.Create;
        if FindFirst(strFolder + '*', faAnyFile, sR) = 0 then
        begin
          repeat
            if (sR.Name <> '.') and (sR.Name <> '..') then
            begin
              if (sR.Attr and faDirectory) = faDirectory then
                sLFiles.Add(IncludeTrailingPathDelimiter(sR.Name))
              else
                sLFiles.Add(sR.Name);
            end;
          until FindNext(sR) <> 0;
          FindClose(sR);
        end;

        WriteLn('GiveFileList - ', sLFiles.Count);
        Data.WriteDWord(sLFiles.Count);
        for i := 1 to sLFiles.Count do
        begin
          WriteLn(i, '-', sLFiles[i - 1]);
          Data.WriteAnsiString(sLFiles[i - 1]);
          strFileName := strFolder + sLFiles[i - 1];
          if strFileName[Length(strFileName)] = '\' then
          begin
            if FindFirst(ExcludeTrailingPathDelimiter(strFileName),
              faDirectory, sR) = 0 then
            begin
              dtFileDate := FileDateToDateTime(sR.Time);
              strFileDate := FormatDateTime('yyyy-mm-dd hh:nn', dtFileDate);
            end
            else
              strFileDate := '';
            FindClose(sR);
            intFileSize := 0;
            strCheck := '';
          end
          else
          begin
            intFileSize := FileSize(strFileName);
            intFileDate := FileAge(strFileName);
            strFileDate := '';
            if intFileDate > -1 then
            try
              dtFileDate := FileDateToDateTime(intFileDate);
              strFileDate := FormatDateTime('yyyy-mm-dd hh:nn', dtFileDate);
            except
              strFileDate := '';
            end;
            //strCheck := MD5Print(MD5File(strFilename));
          end;
          Data.WriteDWord(intFileSize);
          Data.WriteAnsiString(strFileDate);
          //Data.WriteAnsiString(strCheck);
        end;

        sLFiles.Free;
      end;
      cmdSendFiles:         // Receive File
      begin
        intFileCount := Data.ReadDWord;
        strDirectory := Data.ReadAnsiString;
        for i := 1 to intFileCount do
        begin
          intFileSize := Data.ReadDWord;
          strChecksum := Data.ReadAnsiString;
          strFileName := Data.ReadAnsiString;
          strFileName := strDirectory + strFileName;

          Write('GetFile ', i, '/', intFileCount, ' = ', strFileName);
          ForceDirectories(ExtractFileDir(strFilename));
          boolSaveFileOk := True;
          try
            FileStream := TFileStream.Create(strFileName, fmCreate);
          except
            boolSaveFileOk := False;
          end;

          if boolSaveFileOk then
          begin
            if intFileSize > 0 then
            begin
              Initialize(Buffer, Length(Buffer));
              try
                recFileSize := 0;
                repeat
                  BytesReceived := Data.Read(Buffer, BUFSIZE);
                  FileStream.WriteBuffer(Buffer, BytesReceived);
                  Inc(recFileSize, BytesReceived);
                until recFileSize >= intFileSize;
              except
                writeln('error');
              end;
            end;
            FileStream.Free;
          end
          else
            writeln('error writing file');

          strCheck := MD5Print(MD5File(strFilename, BUFSIZE));
          Writeln('  ', strChecksum, '-', strCheck);
          Data.WriteAnsiString(strCheck);
          BytesReceived := 0;
        end;
        Writeln('done');
      end;
      cmdDeleteFiles:
      begin
        intFileCount := Data.ReadDWord;
        strDirectory := Data.ReadAnsiString;
        WriteLn('DeleteFiles ', intFileCount);
        for i := 1 to intFileCount do
        begin
          strFileName := Data.ReadAnsiString;
          WriteLn(i, '-', strFileName);
          strFileName := IncludeTrailingPathDelimiter(strDirectory) + strFileName;
          if DirectoryExists(strFileName) then
            if DeleteDirectory(strFileName, True) then
            begin
              RemoveDir(strFileName);
              intOperationCode := intOperationError;
              if DirectoryExists(strFileName) then
                intOperationCode := intOperationOk;
            end;
          if FileExists(strFileName) then
          begin
            DeleteFile(strFileName);
            intOperationCode := intOperationError;
            if FileExists(strFileName) then
              intOperationCode := intOperationOk;
          end;
          Data.WriteByte(intOperationCode);
        end;
      end;
      cmdCreateDirectory:
      begin
        strDirectoryNew := Data.ReadAnsiString;
        strDirectoryNew := IncludeTrailingPathDelimiter(strDirectoryNew);
        WriteLn('Create folder - ', strDirectoryNew);
        ForceDirectories(strDirectoryNew);
        if DirectoryExists(strDirectoryNew) then
          intOperationCode := intOperationOk
        else
          intOperationCode := intOperationError;
        Data.WriteByte(intOperationCode);
      end;
      cmdRenameDirectory:
      begin
        strItemOld := Data.ReadAnsiString;
        strItemNew := Data.ReadAnsiString;

        if DirectoryExists(strItemOld) then
        begin
          strItemOld := IncludeTrailingPathDelimiter(strItemOld);
          strItemNew := IncludeTrailingPathDelimiter(strItemNew);
        end;

        WriteLn('Rename folder ', strItemOld);
        if RenameFile(strItemOld, strItemNew) and
          (DirectoryExists(strItemOld) or FileExists(strItemOld)) then
          intOperationCode := intOperationOk
        else
          intOperationCode := intOperationError;
        writeln(1);
        Data.WriteByte(intOperationCode);
        writeln(2);
      end;
      cmdSizeDirectory:
      begin
        intFileCount := Data.ReadDWord;
        //strDirectory := Data.ReadAnsiString;
        //Writeln('Size Directory ', intFileCount, '-', strDirectory);
        for i := 1 to intFileCount do
        begin
          strFolder := Data.ReadAnsiString;
          intFileSize := DirectorySize({strDirectory + }strFolder, True);
          Writeln('SizeDirectory ', i, '/', intFileCount, ' = ',
            strFolder, ' = ', intFileSize);
          Data.WriteAnsiString(strFolder);
          Data.WriteDWord(intFileSize);
        end;
      end;
      cmdChecksumFiles:
      begin
        intFileCount := Data.ReadDWord;
        //strDirectory := Data.ReadAnsiString;
        //Writeln('Size Directory ', intFileCount, '-', strDirectory);
        for i := 1 to intFileCount do
        begin
          strFileName := Data.ReadAnsiString;
          strCheck := MD5Print(MD5File(strFilename, BUFSIZE));
          Writeln('File checksum ', i, '/', intFileCount, ' = ',
            strFileName, ' = ', strCheck);
          Data.WriteAnsiString(strFileName);
          Data.WriteAnsiString(strCheck);
        end;
      end;
      //else           writeln('Error');
    end;
  end;

  procedure TInetServerApp.Run;
  begin
    FServer.StartAccepting;
  end;

var
  Application: TInetServerApp;
  sL: TStringList;

begin
  // ipconfig/all | find "IP" | find "Address"
  intPort := 1212;
  strDirectory := ExtractFileDir(ParamStr(0));
  if ParamCount >= 1 then
    intPort := StrToInt(ParamStr(1));
  if ParamCount >= 2 then
    strDirectory := ParamStr(2);
  strDirectory := IncludeTrailingPathDelimiter(strDirectory);

  sL := TStringList.Create;
  strExeChecksum := MD5Print(MD5File(ParamStr(0)));
  WriteLn('   Checksum: ', strExeChecksum);
  if RunCmd('ipconfig/all | find "IP" | find "Address"', sL) then
  begin
    strIP := sL.Text;
    strIP := Copy(strIP, 1, Pos(#13, strIP) - 1);
    strIP := Copy(strIP, Pos(':', strIP) + 1, Length(strIP));
    WriteLn('   IP: ', strIP);

  end
  else
    WriteLn('Unable to detect local IP');
  WriteLn('   Port: ', intPort);
  WriteLn('   Folder: ', strDirectory);

  Application := TInetServerApp.Create(intPort);
  Application.Run;
  Application.Free;
end.
