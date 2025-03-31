{ ... }:
{
  home-manager.sharedModules = [
    {
      home.file.".local/share/gpt/default.aichat".source = ./default.aichat;
      home.file.".local/share/gpt/o3-mini.aichat".source = ./o3-mini.aichat;
    }
  ];
}
