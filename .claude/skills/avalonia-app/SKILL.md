---
name: avalonia-app
description: Write or extend a cross-platform desktop app with Avalonia UI (.NET), or port a WPF app to Avalonia for Linux and macOS while sharing its view models. Covers project setup, compiled bindings, MVVM with CommunityToolkit, sync dialogs over Avalonia's async ones, localization markup, light/dark theme dictionaries, custom controls, icons and logos, platform services (audio, secrets, speech, opening folders), keyboard handling, CI on Windows/Linux/macOS, and smoke-testing the window from a Windows shell. Use for "Avalonia", "cross-platform desktop app", "Linux/macOS version of the WPF app", or .axaml files.
---

# Avalonia desktop app (.NET)

Drawn from PodcastRecorder (`src/PodcastRecorder.Avalonia`, Avalonia 12, .NET 10), a WPF app ported
to Linux and macOS with the view models shared. Read that repo for full examples when available.
For a double-clickable Mac build, use the **macos-app-bundle** skill afterwards.

## Project

```xml
<OutputType>WinExe</OutputType>
<TargetFramework>net10.0</TargetFramework>
<AvaloniaUseCompiledBindingsByDefault>true</AvaloniaUseCompiledBindingsByDefault>
<ApplicationIcon>..\..\assets\logo\logo.ico</ApplicationIcon>   <!-- exe icon on Windows -->
...
<PackageReference Include="Avalonia" Version="12.x" />            <!-- keep all Avalonia.* on one version -->
<PackageReference Include="Avalonia.Desktop" Version="12.x" />
<PackageReference Include="Avalonia.Themes.Fluent" Version="12.x" />
<PackageReference Include="Avalonia.Fonts.Inter" Version="12.x" />
<PackageReference Include="CommunityToolkit.Mvvm" Version="8.x" />
```

`Program.Main`: `AppBuilder.Configure<App>().UsePlatformDetect().WithInterFont().LogToTrace()` then
`StartWithClassicDesktopLifetime(args)`. In `App.OnFrameworkInitializationCompleted`, build services
and the main view model, set `desktop.MainWindow`, call long setup from `window.Opened`, dispose on
`desktop.Exit`.

## Sharing code with a WPF app

- Keep view models and settings free of WPF types, then compile the same files into both apps:
  `<Compile Include="..\App\ViewModels\*.cs" Link="Shared\ViewModels\%(Filename)%(Extension)" />`.
  Link resx files the same way (`EmbeddedResource ... Link=`) so both apps read one set of texts.
- Put everything platform-specific behind small interfaces the view models take in their
  constructor (`IFileDialogs`, `ILiveSettingsDialog`, `IAudioBackend`…), with one implementation
  per UI or OS. Pick the OS implementation in one place: `OperatingSystem.IsWindows() ? new X() : new Y()`.
- Files only one app compiles (WPF markup extensions, WPF dialogs) move out of the shared folders.
- Plain helpers that tests need (no UI types) go in their own file so the test project can compile
  them with `<Compile Include=... Link=...>`; the UI projects target frameworks tests cannot reference.

## Dialogs

Avalonia dialogs are async (`ShowDialog<T>(owner)`, `StorageProvider.OpenFilePickerAsync`). When
shared view models expect a synchronous answer, as WPF gave them, wait on a nested dispatcher frame
instead of blocking:

```csharp
internal static class Modal
{
    public static T Wait<T>(Task<T> task)
    {
        if (!task.IsCompleted)
        {
            var frame = new DispatcherFrame();
            task.ContinueWith(_ => frame.Continue = false, TaskScheduler.Default);
            Dispatcher.UIThread.PushFrame(frame);
        }
        return task.GetAwaiter().GetResult();
    }
}
```

Look the owner window up per call (`app.MainWindow`); it changes if the window is rebuilt. File
pickers return `IStorageFile`; `TryGetLocalPath()` gives the path. A dialog window closes with
`Close(result)`.

## XAML

- Compiled bindings need `x:DataType="vm:MainViewModel"` on the root (and on DataTemplates).
  Binding to another element works with `{Binding $parent[Window].Title}` or `#ElementName.Prop`.
- `Classes="panel"` plus `Style Selector="Border.panel"` replaces WPF's keyed styles;
  `Classes.alert="{Binding IsRecording}"` toggles a class from a bool.
- Tooltips: `ToolTip.Tip="..."`. Images and icons: `avares://<AssemblyName>/Assets/x.png`, with the file
  added as `<AvaloniaResource Include="..\..\assets\logo\png\256.png" Link="Assets\logo.png" />`. Set
  `Icon=` on every Window (the taskbar and Alt-Tab use it); in code, `new Bitmap(AssetLoader.Open(uri))`.
- Localization: a markup extension class with `ProvideValue(IServiceProvider)` returning the string
  (`{loc:T Key}`). To switch language at runtime, rebuild the main window over the same view model
  (copy position, size, state) instead of making every text observable.
- Theme: `<FluentTheme />` in `Application.Styles`, app colours in
  `ResourceDictionary.ThemeDictionaries` (keys `Light` and `Dark`) used with `{DynamicResource}`;
  switch with `Application.Current.RequestedThemeVariant = ThemeVariant.Light/Dark/Default`.
- A custom drawn control: derive from `Control`, register `StyledProperty`s, call
  `AffectsRender<T>(...)` in the static constructor, draw in `Render(DrawingContext)`.
- Render model or user text as text (TextBlock.Text), never as markup.

## Keyboard and input

- `Window.KeyBindings` with `KeyBinding Gesture="Ctrl+R"` for shortcuts with modifiers.
- Plain letter/digit keys (and F1) are handled in code-behind with
  `AddHandler(KeyDownEvent, handler, RoutingStrategies.Bubble)`; ignore them while a TextBox has focus.
- To ignore auto-repeat (PodcastRecorder does it without a repeat flag), keep a set of held keys, remove on KeyUp (Tunnel) and **clear it on
  `Deactivated`**, or a key released in another window stays "held" and the next press is ignored.
- `SelectionChanged` bubbles up from child ComboBoxes; check `ReferenceEquals(e.Source, theControl)`.
- Drag and drop inside the app: `DataFormat.CreateInProcessFormat<string>("App.Item")`; files from
  the OS through `DragDrop.DragOverEvent` / `DropEvent` handlers added with `AddHandler`.

## Platform services that differ

| Need | Windows | Linux | macOS |
| --- | --- | --- | --- |
| Audio devices | WASAPI (NAudio) | PortAudio (`org.k2fsa.portaudio.runtime.*` packages ship the native lib) | PortAudio (Core Audio) |
| MP3 encode | NAudio.Lame's DLL | system libmp3lame (`apt install libmp3lame0`) | `brew install lame`; also try `/opt/homebrew/lib`, `/usr/local/lib` |
| Decode FLAC/M4A/AAC | Media Foundation | ffmpeg into a cached WAV | same; look for ffmpeg in Homebrew folders (Finder gives no shell PATH) |
| Secrets | DPAPI | AES-GCM, key file 0600 in the settings folder | same |
| Local TTS | System.Speech voices | `espeak-ng` | `say` |
| Show a folder | `explorer.exe` | `xdg-open` | `open -R file` |
| Settings folder | %APPDATA% | `~/.config` | `~/Library/Application Support` |

Rules learned the hard way:
- Create private files with `FileStreamOptions.UnixCreateMode` / `Directory.CreateDirectory(path, UnixFileMode)`
  (guard with `OperatingSystem.IsWindows()` for the analyzer). Never put user data in shared `/tmp`; use
  the per-user cache (`$XDG_CACHE_HOME` or `~/.cache`, `~/Library/Caches`).
- Concurrent writers to one cache file: write to a unique temp name, `File.Move(temp, final, overwrite: false)`,
  and use the existing file when that move finds one.
- macOS refuses socket options (EINVAL) on a connection the peer already reset: set
  `TcpClient.SendTimeout`/`ReceiveTimeout` before `ConnectAsync`, not on the stream afterwards.
- Device ids from names are not unique (two identical USB mics): add "#2", "#3" in one function
  used for listing, defaults and opening.
- If a native resource's `Start()` throws before you store it, dispose it there.

## CI

A GitHub Actions matrix: the Windows job builds the whole solution (WPF needs Windows), an
`ubuntu-latest` and `macos-latest` job builds the Avalonia project and runs the tests after
installing native deps (`apt-get install libmp3lame0 ffmpeg`, `brew install lame ffmpeg`). Mark
tests that need a tool or OS feature to return early when it is missing; xUnit 2 has no runtime skip.
Release: `dotnet publish --runtime linux-x64|osx-arm64|osx-x64 --self-contained` per matrix entry.

## Checking the running app from a Windows shell

Compilation is not proof. After a change, start the exe from the Release build and check it:

- `Start-Process` then after a few seconds `$p.HasExited` and `$p.MainWindowTitle`.
- Do **not** send keys with SendKeys: if the window is not in front the keys go to another app.
  Press buttons with UI Automation instead: find the Button by name under
  `AutomationElement.FromHandle($p.MainWindowHandle)` and call `InvokePattern.Invoke()`. Find dialogs
  by `ProcessIdProperty` among `RootElement` descendants with ControlType Window.
- Screenshot one window, even behind others, with `PrintWindow(hwnd, hdc, 2)` (PW_RENDERFULLCONTENT)
  via a tiny P/Invoke `Add-Type`, and draw the bitmap in PowerShell (System.Drawing types do not
  compile inside `Add-Type` on PowerShell 7).
- Close with `CloseMainWindow()`, then `Stop-Process` if it is still running.
