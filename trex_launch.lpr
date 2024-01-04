program trex_launch;

uses
  SysUtils,
  ShellApi,
  Classes;

var
  strOldFile, strNewFile, strParameters: string;
  i: integer;

begin
  strNewFile := 'C:\TEMP\trex_client_new.exe';
    strOldFile := 'C:\TEMP\trex_client.exe';
    if DeleteFile(strOldFile) then
      if RenameFile(strNewFile, strOldFile) then
        ShellExecute(0, nil, PChar(strOldFile), PChar('1212 C:\TEMP\'), nil, 1);


  {if ParamCount >= 2 then
  begin
    strNewFile := ParamStr(1);
    strOldFile := ParamStr(2);

    strParameters := '';
    for i := 3 to ParamCount do
      strParameters := strParameters + ' ' + ParamStr(i);

    with TStringList.Create do
    begin
      Add(strNewFile);
      Add(strOldFile);
      Add(strParameters);

      Sleep(5000);

      if FileExists(strNewFile) then
      begin
        Add(strNewFile + ' exists');
        if FileExists(strOldFile) then
        begin
          Add(strOldFile + ' exists');
          if DeleteFile(strOldFile) then
          begin
            Add(strOldFile + ' deleted');
            if RenameFile(strNewFile, strOldFile) and FileExists(strOldFile) then
            begin
              Add(strOldFile + ' will launch');
              ShellExecute(0, nil, PChar(strOldFile), PChar(strParameters), nil, 1);
              Writeln(strParameters);
            end;
          end
          else Add(strOldFile + ' not deleted!');
        end;
      end
      else
        Add(strNewFile + ' not found');
      SaveToFile('C:\TEMP\update.log');
    end;
  end;  }
end.
