use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use niri_ipc::socket::Socket;
use niri_ipc::{
    Action, Event, Output, Request, Response, SizeChange, Window, Workspace, WorkspaceReferenceArg,
};
use regex::RegexBuilder;
use serde::{Deserialize, Serialize};

const STAGE_WORKSPACE: &str = "__niri_stage";
const EMPTY_WORKSPACE_GRACE: Duration = Duration::from_secs(0);
const RECONCILE_DEBOUNCE: Duration = Duration::from_millis(100);
const LAUNCH_TIMEOUT: Duration = Duration::from_secs(20);

const FALLBACK_MANAGED_WORKSPACES: &[&str] = &[
    "ghostty", "Slack", "Signal", "Brave", "Spotify", "Caprine", "Steam", "Discord", "nas",
    "agent", "rozzy", "bottom", "grill", "Windows", "Teams", "1", "2", "3", "4", "5", "6", "7",
    "8", "9", "0",
];

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
enum CompanionCommand {
    Launch {
        workspace: String,
        command: String,
        app_id_regex: Option<String>,
        title_regex: Option<String>,
        pull: bool,
    },
    Bring {
        workspace: String,
        app_id_regex: Option<String>,
        title_regex: Option<String>,
    },
    MoveFocused {
        workspace: String,
        follow: bool,
    },
    FocusWorkspace {
        workspace: String,
    },
    ToggleWorkspaceWidth,
    ToggleColumnWidth,
    FocusColumn {
        direction: Direction,
    },
    MoveColumn {
        direction: Direction,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
enum Direction {
    Left,
    Right,
}

#[derive(Debug, Serialize, Deserialize)]
struct CompanionReply {
    ok: bool,
    error: Option<String>,
}

#[derive(Debug, Default)]
struct State {
    windows: Vec<Window>,
    workspaces: Vec<Workspace>,
    outputs: HashMap<String, Output>,
    empty_named_since: HashMap<String, Instant>,
}

#[derive(Debug)]
struct Shared {
    state: Mutex<State>,
    changed: Condvar,
}

fn main() {
    let result = run();
    if let Err(error) = result {
        eprintln!("niri-companion: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1).collect::<Vec<_>>();
    let Some(subcommand) = args.first().cloned() else {
        return Err(usage());
    };
    args.remove(0);

    match subcommand.as_str() {
        "daemon" => run_daemon(),
        "launch" => send_client_command(parse_launch(args)?),
        "bring" => send_client_command(parse_bring(args)?),
        "move-focused" => send_client_command(parse_move_focused(args)?),
        "focus-workspace" => send_client_command(parse_focus_workspace(args)?),
        "toggle-workspace-width" => send_client_command(CompanionCommand::ToggleWorkspaceWidth),
        "toggle-column-width" => send_client_command(CompanionCommand::ToggleColumnWidth),
        "focus-column" => send_client_command(parse_focus_column(args)?),
        "move-column" => send_client_command(parse_move_column(args)?),
        "help" | "--help" | "-h" => Err(usage()),
        other => Err(format!("unknown subcommand: {other}\n{}", usage())),
    }
}

fn usage() -> String {
    "usage: niri-companion daemon | launch --workspace NAME [--app-id-regex RE] [--title-regex RE] [--pull] --command CMD | bring --workspace NAME [--app-id-regex RE] [--title-regex RE] | move-focused --workspace NAME [--no-follow] | focus-workspace --workspace NAME | toggle-workspace-width | toggle-column-width | focus-column left|right | move-column left|right".to_string()
}

fn parse_launch(args: Vec<String>) -> Result<CompanionCommand, String> {
    let mut workspace = None;
    let mut command = None;
    let mut app_id_regex = None;
    let mut title_regex = None;
    let mut pull = false;
    let mut iter = args.into_iter();

    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--workspace" => workspace = iter.next(),
            "--command" => command = iter.next(),
            "--app-id-regex" => app_id_regex = iter.next(),
            "--title-regex" => title_regex = iter.next(),
            "--pull" => pull = true,
            other => return Err(format!("unknown launch argument: {other}")),
        }
    }

    Ok(CompanionCommand::Launch {
        workspace: workspace.ok_or("launch requires --workspace")?,
        command: command.ok_or("launch requires --command")?,
        app_id_regex,
        title_regex,
        pull,
    })
}

fn parse_bring(args: Vec<String>) -> Result<CompanionCommand, String> {
    let mut workspace = None;
    let mut app_id_regex = None;
    let mut title_regex = None;
    let mut iter = args.into_iter();

    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--workspace" => workspace = iter.next(),
            "--app-id-regex" => app_id_regex = iter.next(),
            "--title-regex" => title_regex = iter.next(),
            other => return Err(format!("unknown bring argument: {other}")),
        }
    }

    Ok(CompanionCommand::Bring {
        workspace: workspace.ok_or("bring requires --workspace")?,
        app_id_regex,
        title_regex,
    })
}

fn parse_move_focused(args: Vec<String>) -> Result<CompanionCommand, String> {
    let mut workspace = None;
    let mut follow = true;
    let mut iter = args.into_iter();

    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--workspace" => workspace = iter.next(),
            "--no-follow" => follow = false,
            other => return Err(format!("unknown move-focused argument: {other}")),
        }
    }

    Ok(CompanionCommand::MoveFocused {
        workspace: workspace.ok_or("move-focused requires --workspace")?,
        follow,
    })
}

fn parse_focus_workspace(args: Vec<String>) -> Result<CompanionCommand, String> {
    let mut workspace = None;
    let mut iter = args.into_iter();

    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--workspace" => workspace = iter.next(),
            other => return Err(format!("unknown focus-workspace argument: {other}")),
        }
    }

    Ok(CompanionCommand::FocusWorkspace {
        workspace: workspace.ok_or("focus-workspace requires --workspace")?,
    })
}

fn parse_focus_column(args: Vec<String>) -> Result<CompanionCommand, String> {
    Ok(CompanionCommand::FocusColumn {
        direction: parse_direction(args.first())?,
    })
}

fn parse_move_column(args: Vec<String>) -> Result<CompanionCommand, String> {
    Ok(CompanionCommand::MoveColumn {
        direction: parse_direction(args.first())?,
    })
}

fn parse_direction(value: Option<&String>) -> Result<Direction, String> {
    match value.map(String::as_str) {
        Some("left") => Ok(Direction::Left),
        Some("right") => Ok(Direction::Right),
        Some(other) => Err(format!("unknown direction: {other}")),
        None => Err("missing direction: left|right".to_string()),
    }
}

fn send_client_command(command: CompanionCommand) -> Result<(), String> {
    let socket_path = companion_socket_path()?;
    let mut stream = UnixStream::connect(&socket_path)
        .map_err(|error| format!("failed to connect to {}: {error}", socket_path.display()))?;

    let mut request = serde_json::to_string(&command).map_err(|error| error.to_string())?;
    request.push('\n');
    stream
        .write_all(request.as_bytes())
        .map_err(|error| format!("failed to write companion request: {error}"))?;

    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|error| format!("failed to read companion reply: {error}"))?;
    let reply: CompanionReply = serde_json::from_str(&line)
        .map_err(|error| format!("failed to parse companion reply: {error}: {line}"))?;

    if reply.ok {
        Ok(())
    } else {
        Err(reply
            .error
            .unwrap_or_else(|| "companion command failed".to_string()))
    }
}

fn run_daemon() -> Result<(), String> {
    let shared = Arc::new(Shared {
        state: Mutex::new(State::default()),
        changed: Condvar::new(),
    });

    let event_shared = Arc::clone(&shared);
    thread::spawn(move || event_loop(event_shared));

    let socket_path = companion_socket_path()?;
    if socket_path.exists() {
        fs::remove_file(&socket_path).map_err(|error| {
            format!(
                "failed to remove stale socket {}: {error}",
                socket_path.display()
            )
        })?;
    }

    let listener = UnixListener::bind(&socket_path)
        .map_err(|error| format!("failed to bind {}: {error}", socket_path.display()))?;
    eprintln!("niri-companion: listening on {}", socket_path.display());

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let shared = Arc::clone(&shared);
                thread::spawn(move || handle_client(stream, shared));
            }
            Err(error) => eprintln!("niri-companion: failed to accept client: {error}"),
        }
    }

    Ok(())
}

fn event_loop(shared: Arc<Shared>) {
    loop {
        match stream_events_once(&shared) {
            Ok(()) => eprintln!("niri-companion: event stream ended"),
            Err(error) => eprintln!("niri-companion: event stream failed: {error}"),
        }
        thread::sleep(Duration::from_secs(1));
    }
}

fn stream_events_once(shared: &Arc<Shared>) -> Result<(), String> {
    let mut socket =
        Socket::connect().map_err(|error| format!("failed to connect to niri: {error}"))?;
    let reply = socket
        .send(Request::EventStream)
        .map_err(|error| format!("failed to request event stream: {error}"))?;
    match reply {
        Ok(Response::Handled) => {}
        Ok(other) => return Err(format!("unexpected event stream response: {other:?}")),
        Err(error) => return Err(format!("niri rejected event stream: {error}")),
    }

    let mut read_event = socket.read_events();

    loop {
        let event = read_event().map_err(|error| format!("failed to read event: {error}"))?;
        let relevant = update_state(shared, event);
        if relevant {
            thread::sleep(RECONCILE_DEBOUNCE);
            if let Err(error) = refresh_state(shared).and_then(|_| reconcile(shared)) {
                eprintln!("niri-companion: reconcile failed: {error}");
            }
        }
    }
}

fn update_state(shared: &Arc<Shared>, event: Event) -> bool {
    let mut state = shared.state.lock().expect("state poisoned");
    let relevant = match event {
        Event::WorkspacesChanged { workspaces } => {
            state.workspaces = workspaces;
            true
        }
        Event::WindowsChanged { windows } => {
            state.windows = windows;
            true
        }
        Event::WindowOpenedOrChanged { window } => {
            if window.is_focused {
                for existing in &mut state.windows {
                    existing.is_focused = false;
                }
            }
            upsert_window(&mut state.windows, window);
            true
        }
        Event::WindowClosed { id } => {
            state.windows.retain(|window| window.id != id);
            true
        }
        Event::WorkspaceActivated { id, focused } => {
            if focused {
                for workspace in &mut state.workspaces {
                    workspace.is_focused = workspace.id == id;
                }
            }
            if let Some(output) = state
                .workspaces
                .iter()
                .find(|workspace| workspace.id == id)
                .and_then(|workspace| workspace.output.clone())
            {
                for workspace in &mut state.workspaces {
                    if workspace.output.as_ref() == Some(&output) {
                        workspace.is_active = workspace.id == id;
                    }
                }
            }
            true
        }
        Event::WorkspaceActiveWindowChanged {
            workspace_id,
            active_window_id,
        } => {
            if let Some(workspace) = state
                .workspaces
                .iter_mut()
                .find(|workspace| workspace.id == workspace_id)
            {
                workspace.active_window_id = active_window_id;
            }
            true
        }
        Event::WindowFocusChanged { id } => {
            for window in &mut state.windows {
                window.is_focused = Some(window.id) == id;
            }
            true
        }
        Event::WindowLayoutsChanged { changes } => {
            for (id, layout) in changes {
                if let Some(window) = state.windows.iter_mut().find(|window| window.id == id) {
                    window.layout = layout;
                }
            }
            true
        }
        _ => false,
    };

    if relevant {
        shared.changed.notify_all();
    }

    relevant
}

fn upsert_window(windows: &mut Vec<Window>, window: Window) {
    if let Some(existing) = windows.iter_mut().find(|existing| existing.id == window.id) {
        *existing = window;
    } else {
        windows.push(window);
    }
}

fn handle_client(mut stream: UnixStream, shared: Arc<Shared>) {
    let result = handle_client_inner(&mut stream, shared);
    let reply = match result {
        Ok(()) => CompanionReply {
            ok: true,
            error: None,
        },
        Err(error) => CompanionReply {
            ok: false,
            error: Some(error),
        },
    };

    if let Ok(mut response) = serde_json::to_string(&reply) {
        response.push('\n');
        let _ = stream.write_all(response.as_bytes());
    }
}

fn handle_client_inner(stream: &mut UnixStream, shared: Arc<Shared>) -> Result<(), String> {
    let mut line = String::new();
    BufReader::new(stream.try_clone().map_err(|error| error.to_string())?)
        .read_line(&mut line)
        .map_err(|error| format!("failed to read request: {error}"))?;
    let command: CompanionCommand = serde_json::from_str(&line)
        .map_err(|error| format!("invalid companion request: {error}: {line}"))?;

    process_command(command, &shared)
}

fn process_command(command: CompanionCommand, shared: &Arc<Shared>) -> Result<(), String> {
    wait_for_initial_state(shared, Duration::from_secs(2))?;

    match command {
        CompanionCommand::Launch {
            workspace,
            command,
            app_id_regex,
            title_regex,
            pull,
        } => launch_app(
            shared,
            &workspace,
            &command,
            app_id_regex,
            title_regex,
            pull,
        ),
        CompanionCommand::Bring {
            workspace: _,
            app_id_regex,
            title_regex,
        } => bring_app_here(shared, app_id_regex, title_regex),
        CompanionCommand::MoveFocused { workspace, follow } => {
            move_focused_to_workspace(shared, &workspace, follow)
        }
        CompanionCommand::FocusWorkspace { workspace } => focus_named_workspace(shared, &workspace),
        CompanionCommand::ToggleWorkspaceWidth => toggle_workspace_width(shared),
        CompanionCommand::ToggleColumnWidth => toggle_column_width(shared),
        CompanionCommand::FocusColumn { direction } => niri_action(match direction {
            Direction::Left => Action::FocusColumnLeft {},
            Direction::Right => Action::FocusColumnRight {},
        }),
        CompanionCommand::MoveColumn { direction } => niri_action(match direction {
            Direction::Left => Action::MoveColumnLeft {},
            Direction::Right => Action::MoveColumnRight {},
        }),
    }
}

fn launch_app(
    shared: &Arc<Shared>,
    workspace: &str,
    command: &str,
    mut app_id_regex: Option<String>,
    title_regex: Option<String>,
    pull: bool,
) -> Result<(), String> {
    if app_id_regex.is_none() && title_regex.is_none() {
        if let Some(first_word) = command.split_whitespace().next() {
            let basename = first_word.rsplit('/').next().unwrap_or(first_word);
            app_id_regex = Some(format!("^{}$", regex::escape(basename)));
        }
    }

    let before = snapshot(shared);
    let existing = find_matching_windows(
        &before.windows,
        app_id_regex.as_deref(),
        title_regex.as_deref(),
    )?;
    if let Some(window) = existing.first() {
        if pull {
            let target = focused_workspace_reference(&before.workspaces)
                .ok_or("cannot determine focused workspace for pull")?;
            niri_action(Action::MoveWindowToWorkspace {
                window_id: Some(window.id),
                reference: target,
                focus: true,
            })?;
        }
        niri_action(Action::FocusWindow { id: window.id })?;
        wait_for_change(shared, RECONCILE_DEBOUNCE);
        refresh_state(shared)?;
        reconcile(shared)?;
        return Ok(());
    }

    let before_ids = before
        .windows
        .iter()
        .map(|window| window.id)
        .collect::<HashSet<_>>();
    // Ask niri to spawn the application instead of spawning it from the
    // long-running companion daemon.  Children spawned directly by the daemon
    // stay in niri-companion.service's cgroup, so a Home Manager sd-switch that
    // restarts niri-companion will kill launched terminals/apps (including tmux
    // panes running rebuilds).  Niri's SpawnSh action puts the app under niri's
    // normal application scope, matching binds written directly in config.kdl.
    niri_action(Action::SpawnSh {
        command: command.to_string(),
    })?;

    let new_window = wait_for_new_window(
        shared,
        &before_ids,
        app_id_regex.as_deref(),
        title_regex.as_deref(),
        LAUNCH_TIMEOUT,
    )?;
    let target_width = workspace_by_name(&before.workspaces, workspace)
        .and_then(|target| workspace_uniform_width(&before, target))
        .unwrap_or(1.0);

    ensure_named_workspace(shared, workspace)?;
    set_width(new_window.id, target_width)?;
    niri_action(Action::MoveWindowToWorkspace {
        window_id: Some(new_window.id),
        reference: WorkspaceReferenceArg::Name(workspace.to_string()),
        focus: false,
    })?;

    wait_for_window_workspace(shared, new_window.id, workspace, Duration::from_secs(2));
    refresh_state(shared)?;
    niri_action(Action::FocusWorkspace {
        reference: WorkspaceReferenceArg::Name(workspace.to_string()),
    })?;
    niri_action(Action::FocusWindow { id: new_window.id })?;

    reconcile(shared)
}

fn bring_app_here(
    shared: &Arc<Shared>,
    app_id_regex: Option<String>,
    title_regex: Option<String>,
) -> Result<(), String> {
    let state = snapshot(shared);
    let target = focused_workspace_reference(&state.workspaces)
        .ok_or("cannot determine focused workspace")?;
    let existing = find_matching_windows(
        &state.windows,
        app_id_regex.as_deref(),
        title_regex.as_deref(),
    )?;
    let Some(window) = existing.first() else {
        return Err("no matching window to bring".to_string());
    };

    niri_action(Action::MoveWindowToWorkspace {
        window_id: Some(window.id),
        reference: target,
        focus: true,
    })?;
    niri_action(Action::FocusWindow { id: window.id })?;
    wait_for_change(shared, RECONCILE_DEBOUNCE);
    refresh_state(shared)?;
    reconcile(shared)
}

fn focus_named_workspace(shared: &Arc<Shared>, workspace: &str) -> Result<(), String> {
    ensure_named_workspace(shared, workspace)?;
    wait_for_change(shared, RECONCILE_DEBOUNCE);
    refresh_state(shared)?;
    reconcile(shared)
}

fn toggle_workspace_width(shared: &Arc<Shared>) -> Result<(), String> {
    refresh_state(shared)?;
    let state = snapshot(shared);
    let workspace =
        focused_workspace(&state.workspaces).ok_or("cannot determine focused workspace")?;
    let tiled = tiled_windows_for_workspace(&state.windows, workspace.id);
    if tiled.is_empty() {
        return Ok(());
    }

    let width = if workspace_has_full_width_tile(&state, workspace, &tiled) {
        0.5
    } else {
        1.0
    };
    for window in tiled {
        set_width(window.id, width)?;
    }
    wait_for_change(shared, RECONCILE_DEBOUNCE);
    refresh_state(shared)?;
    reconcile(shared)
}

fn toggle_column_width(shared: &Arc<Shared>) -> Result<(), String> {
    refresh_state(shared)?;
    let state = snapshot(shared);
    let workspace =
        focused_workspace(&state.workspaces).ok_or("cannot determine focused workspace")?;
    let window = state
        .windows
        .iter()
        .find(|window| {
            window.is_focused && window.workspace_id == Some(workspace.id) && !window.is_floating
        })
        .ok_or("no focused tiled window")?;
    let width = if workspace_has_full_width_tile(&state, workspace, std::slice::from_ref(window)) {
        0.5
    } else {
        1.0
    };

    set_width(window.id, width)?;
    wait_for_change(shared, RECONCILE_DEBOUNCE);
    refresh_state(shared)?;
    reconcile(shared)
}

fn move_focused_to_workspace(
    shared: &Arc<Shared>,
    workspace: &str,
    _follow: bool,
) -> Result<(), String> {
    let before = snapshot(shared);
    let focused_window_id = before
        .windows
        .iter()
        .find(|window| window.is_focused)
        .map(|window| window.id)
        .ok_or("no focused window to move")?;
    let target_width = workspace_by_name(&before.workspaces, workspace)
        .and_then(|target| workspace_uniform_width(&before, target))
        .unwrap_or(1.0);

    ensure_named_workspace_without_refocus(shared, workspace)?;
    set_width(focused_window_id, target_width)?;
    niri_action(Action::MoveWindowToWorkspace {
        window_id: Some(focused_window_id),
        reference: WorkspaceReferenceArg::Name(workspace.to_string()),
        focus: true,
    })?;
    wait_for_change(shared, RECONCILE_DEBOUNCE);
    refresh_state(shared)?;
    reconcile(shared)
}

fn ensure_named_workspace_without_refocus(
    shared: &Arc<Shared>,
    name: &str,
) -> Result<Workspace, String> {
    if let Some(existing) = workspace_by_name(&snapshot(shared).workspaces, name).cloned() {
        return Ok(existing);
    }

    ensure_named_workspace(shared, name)
}

fn ensure_named_workspace(shared: &Arc<Shared>, name: &str) -> Result<Workspace, String> {
    if let Some(existing) = workspace_by_name(&snapshot(shared).workspaces, name).cloned() {
        niri_action(Action::FocusWorkspace {
            reference: WorkspaceReferenceArg::Name(name.to_string()),
        })?;
        return Ok(existing);
    }

    for _ in 0..20 {
        let state = snapshot(shared);
        if let Some(workspace) = focused_workspace(&state.workspaces) {
            if workspace.name.as_deref() == Some(STAGE_WORKSPACE) {
                niri_action(Action::FocusWorkspaceDown {})?;
                wait_for_change(shared, Duration::from_millis(50));
                continue;
            }

            if all_windows_for_workspace(&state.windows, workspace.id).is_empty() {
                niri_action(Action::SetWorkspaceName {
                    name: name.to_string(),
                    workspace: None,
                })?;
                if let Some(workspace) =
                    wait_for_workspace_name(shared, name, Duration::from_secs(2))
                {
                    return Ok(workspace);
                }
            }
        }

        niri_action(Action::FocusWorkspaceDown {})?;
        wait_for_change(shared, Duration::from_millis(50));
    }

    niri_action(Action::SetWorkspaceName {
        name: name.to_string(),
        workspace: None,
    })?;
    wait_for_workspace_name(shared, name, Duration::from_secs(2))
        .or_else(|| focused_workspace(&snapshot(shared).workspaces).cloned())
        .ok_or_else(|| format!("failed to create workspace {name}"))
}

fn refresh_state(shared: &Arc<Shared>) -> Result<(), String> {
    let mut socket =
        Socket::connect().map_err(|error| format!("failed to connect to niri: {error}"))?;

    let workspaces = match socket
        .send(Request::Workspaces)
        .map_err(|error| format!("failed to request workspaces: {error}"))?
    {
        Ok(Response::Workspaces(workspaces)) => workspaces,
        Ok(other) => return Err(format!("unexpected workspaces response: {other:?}")),
        Err(error) => return Err(format!("niri rejected workspaces request: {error}")),
    };

    let windows = match socket
        .send(Request::Windows)
        .map_err(|error| format!("failed to request windows: {error}"))?
    {
        Ok(Response::Windows(windows)) => windows,
        Ok(other) => return Err(format!("unexpected windows response: {other:?}")),
        Err(error) => return Err(format!("niri rejected windows request: {error}")),
    };

    let outputs = match socket
        .send(Request::Outputs)
        .map_err(|error| format!("failed to request outputs: {error}"))?
    {
        Ok(Response::Outputs(outputs)) => outputs,
        Ok(other) => return Err(format!("unexpected outputs response: {other:?}")),
        Err(error) => return Err(format!("niri rejected outputs request: {error}")),
    };

    let mut state = shared.state.lock().expect("state poisoned");
    state.workspaces = workspaces;
    state.windows = windows;
    state.outputs = outputs;
    shared.changed.notify_all();
    Ok(())
}

fn reconcile(shared: &Arc<Shared>) -> Result<(), String> {
    let state = snapshot(shared);
    ensure_focused_split_workspace_view(&state)?;
    cleanup_empty_workspace_names(shared, &state)
}

fn ensure_focused_split_workspace_view(state: &State) -> Result<(), String> {
    let Some(workspace) = focused_workspace(&state.workspaces) else {
        return Ok(());
    };
    if workspace.name.as_deref() == Some(STAGE_WORKSPACE) {
        return Ok(());
    }

    let half_width = half_width_tiled_windows(state, workspace);
    if half_width.len() < 2 {
        return Ok(());
    }

    // niri does not always expose tile positions over IPC. If positions are
    // missing, we cannot distinguish "two half columns are visible" from "only
    // one half column is visible with blank space". Do not issue focus nudges
    // in that ambiguous state, or reconcile will fight itself and flicker.
    if half_width
        .iter()
        .any(|window| window.layout.tile_pos_in_workspace_view.is_none())
    {
        return Ok(());
    }

    if visible_column_count(state, workspace, &half_width) >= 2 {
        return Ok(());
    }

    let Some(focused) = half_width.iter().find(|window| window.is_focused) else {
        return Ok(());
    };
    let focused_column = column_index(focused);
    if focused_column == 0 {
        return Ok(());
    }

    let has_right_neighbor = half_width
        .iter()
        .any(|window| column_index(window) > focused_column);
    let has_left_neighbor = half_width
        .iter()
        .any(|window| column_index(window) < focused_column);

    if has_right_neighbor {
        niri_action(Action::FocusColumnRight {})?;
        niri_action(Action::FocusWindow { id: focused.id })?;
    } else if has_left_neighbor {
        niri_action(Action::FocusColumnLeft {})?;
        niri_action(Action::FocusWindow { id: focused.id })?;
    }

    Ok(())
}

fn cleanup_empty_workspace_names(shared: &Arc<Shared>, state: &State) -> Result<(), String> {
    let managed = managed_workspaces();
    let mut window_counts = HashMap::<u64, usize>::new();
    for window in &state.windows {
        if let Some(workspace_id) = window.workspace_id {
            *window_counts.entry(workspace_id).or_default() += 1;
        }
    }

    let now = Instant::now();
    let mut to_unset = Vec::new();
    {
        let mut locked = shared.state.lock().expect("state poisoned");
        let mut live_empty_names = HashSet::new();

        for workspace in &state.workspaces {
            let Some(name) = workspace.name.as_deref() else {
                continue;
            };
            if !managed.contains(name) {
                continue;
            }
            if workspace.is_focused || workspace.is_active {
                locked.empty_named_since.remove(name);
                continue;
            }

            if window_counts
                .get(&workspace.id)
                .copied()
                .unwrap_or_default()
                > 0
            {
                locked.empty_named_since.remove(name);
                continue;
            }

            live_empty_names.insert(name.to_string());
            let first_empty = locked
                .empty_named_since
                .entry(name.to_string())
                .or_insert(now);
            if now.duration_since(*first_empty) >= EMPTY_WORKSPACE_GRACE {
                to_unset.push(name.to_string());
            }
        }

        locked
            .empty_named_since
            .retain(|name, _| live_empty_names.contains(name));
    }

    for name in to_unset {
        niri_action(Action::UnsetWorkspaceName {
            reference: Some(WorkspaceReferenceArg::Name(name)),
        })?;
    }

    Ok(())
}

fn managed_workspaces() -> HashSet<String> {
    env::var("NIRI_COMPANION_MANAGED_WORKSPACES_JSON")
        .ok()
        .and_then(|value| serde_json::from_str::<Vec<String>>(&value).ok())
        .unwrap_or_else(|| {
            FALLBACK_MANAGED_WORKSPACES
                .iter()
                .map(|name| name.to_string())
                .collect()
        })
        .into_iter()
        .collect()
}

fn niri_action(action: Action) -> Result<(), String> {
    let mut socket =
        Socket::connect().map_err(|error| format!("failed to connect to niri: {error}"))?;
    match socket
        .send(Request::Action(action))
        .map_err(|error| format!("failed to send niri action: {error}"))?
    {
        Ok(Response::Handled) => Ok(()),
        Ok(other) => Err(format!("unexpected niri action response: {other:?}")),
        Err(error) => Err(format!("niri action failed: {error}")),
    }
}

fn workspace_has_full_width_tile(state: &State, workspace: &Workspace, windows: &[Window]) -> bool {
    let Some(output_width) = output_width(state, workspace) else {
        return false;
    };

    windows
        .iter()
        .any(|window| window.layout.tile_size.0 >= output_width * 0.75)
}

fn half_width_tiled_windows(state: &State, workspace: &Workspace) -> Vec<Window> {
    let Some(output_width) = output_width(state, workspace) else {
        return Vec::new();
    };

    tiled_windows_for_workspace(&state.windows, workspace.id)
        .into_iter()
        .filter(|window| {
            let width = window.layout.tile_size.0;
            width >= output_width * 0.35 && width <= output_width * 0.65
        })
        .collect()
}

fn visible_column_count(state: &State, workspace: &Workspace, windows: &[Window]) -> usize {
    let Some(output_width) = output_width(state, workspace) else {
        return 0;
    };

    windows
        .iter()
        .filter(|window| {
            let Some((x, _)) = window.layout.tile_pos_in_workspace_view else {
                return false;
            };
            let width = window.layout.tile_size.0;
            x >= -40.0 && x + width <= output_width + 40.0
        })
        .filter_map(|window| {
            window
                .layout
                .pos_in_scrolling_layout
                .map(|(column, _)| column)
        })
        .collect::<HashSet<_>>()
        .len()
}

fn column_index(window: &Window) -> usize {
    window
        .layout
        .pos_in_scrolling_layout
        .map(|(column, _)| column)
        .unwrap_or_default()
}

fn workspace_uniform_width(state: &State, workspace: &Workspace) -> Option<f64> {
    let output_width = output_width(state, workspace)?;
    let tiled = tiled_windows_for_workspace(&state.windows, workspace.id);
    if tiled.is_empty() {
        return Some(1.0);
    }

    let full_count = tiled
        .iter()
        .filter(|window| window.layout.tile_size.0 >= output_width * 0.75)
        .count();
    if full_count == tiled.len() {
        return Some(1.0);
    }

    let half_count = tiled
        .iter()
        .filter(|window| {
            let width = window.layout.tile_size.0;
            width >= output_width * 0.35 && width <= output_width * 0.65
        })
        .count();
    if half_count == tiled.len() {
        return Some(0.5);
    }

    None
}

fn output_width(state: &State, workspace: &Workspace) -> Option<f64> {
    let output_name = workspace.output.as_deref()?;
    state
        .outputs
        .get(output_name)
        .and_then(|output| output.logical.map(|logical| f64::from(logical.width)))
}

fn set_width(window_id: u64, width: f64) -> Result<(), String> {
    // niri's IPC SizeChange::SetProportion is expressed as a percentage
    // (matching `niri msg action set-window-width 100%`), while the companion
    // internally uses fractional widths matching the KDL `proportion` syntax.
    niri_action(Action::SetWindowWidth {
        id: Some(window_id),
        change: SizeChange::SetProportion(width * 100.0),
    })
}

fn find_matching_windows(
    windows: &[Window],
    app_id_regex: Option<&str>,
    title_regex: Option<&str>,
) -> Result<Vec<Window>, String> {
    let app_re = compile_regex(app_id_regex, true)?;
    let title_re = compile_regex(title_regex, false)?;
    let mut matches = windows
        .iter()
        .filter(|window| {
            app_re
                .as_ref()
                .map(|regex| regex.is_match(window.app_id.as_deref().unwrap_or_default()))
                .unwrap_or(true)
                && title_re
                    .as_ref()
                    .map(|regex| regex.is_match(window.title.as_deref().unwrap_or_default()))
                    .unwrap_or(true)
        })
        .cloned()
        .collect::<Vec<_>>();

    matches.sort_by_key(|window| !window.is_focused);
    Ok(matches)
}

fn compile_regex(
    pattern: Option<&str>,
    case_insensitive: bool,
) -> Result<Option<regex::Regex>, String> {
    pattern
        .map(|pattern| {
            RegexBuilder::new(pattern)
                .case_insensitive(case_insensitive)
                .build()
                .map_err(|error| format!("invalid regex {pattern:?}: {error}"))
        })
        .transpose()
}

fn wait_for_new_window(
    shared: &Arc<Shared>,
    before_ids: &HashSet<u64>,
    app_id_regex: Option<&str>,
    title_regex: Option<&str>,
    timeout: Duration,
) -> Result<Window, String> {
    let deadline = Instant::now() + timeout;
    loop {
        let state = snapshot(shared);
        let stage_id =
            workspace_by_name(&state.workspaces, STAGE_WORKSPACE).map(|workspace| workspace.id);
        let candidates = find_matching_windows(&state.windows, app_id_regex, title_regex)?
            .into_iter()
            .filter(|window| !before_ids.contains(&window.id))
            .collect::<Vec<_>>();

        if let Some(stage_id) = stage_id {
            if let Some(window) = candidates
                .iter()
                .find(|window| window.workspace_id == Some(stage_id))
                .cloned()
            {
                return Ok(window);
            }
        }
        if let Some(window) = candidates.first().cloned() {
            return Ok(window);
        }

        if Instant::now() >= deadline {
            return Err("timed out waiting for launched window".to_string());
        }
        wait_until(
            shared,
            deadline.min(Instant::now() + Duration::from_millis(50)),
        );
    }
}

fn wait_for_initial_state(shared: &Arc<Shared>, timeout: Duration) -> Result<(), String> {
    let deadline = Instant::now() + timeout;
    loop {
        let state = snapshot(shared);
        if !state.workspaces.is_empty() {
            return Ok(());
        }
        if Instant::now() >= deadline {
            return Err("timed out waiting for initial niri state".to_string());
        }
        wait_until(
            shared,
            deadline.min(Instant::now() + Duration::from_millis(50)),
        );
    }
}

fn wait_for_workspace_name(
    shared: &Arc<Shared>,
    name: &str,
    timeout: Duration,
) -> Option<Workspace> {
    let deadline = Instant::now() + timeout;
    loop {
        if let Some(workspace) = workspace_by_name(&snapshot(shared).workspaces, name).cloned() {
            return Some(workspace);
        }
        if Instant::now() >= deadline {
            return None;
        }
        wait_until(
            shared,
            deadline.min(Instant::now() + Duration::from_millis(50)),
        );
    }
}

fn wait_for_window_workspace(
    shared: &Arc<Shared>,
    window_id: u64,
    workspace_name: &str,
    timeout: Duration,
) {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        let state = snapshot(shared);
        let target_id =
            workspace_by_name(&state.workspaces, workspace_name).map(|workspace| workspace.id);
        if state
            .windows
            .iter()
            .any(|window| window.id == window_id && window.workspace_id == target_id)
        {
            return;
        }
        wait_until(
            shared,
            deadline.min(Instant::now() + Duration::from_millis(50)),
        );
    }
}

fn wait_for_change(shared: &Arc<Shared>, timeout: Duration) {
    wait_until(shared, Instant::now() + timeout);
}

fn wait_until(shared: &Arc<Shared>, deadline: Instant) {
    let state = shared.state.lock().expect("state poisoned");
    let now = Instant::now();
    if deadline > now {
        let _ = shared.changed.wait_timeout(state, deadline - now);
    }
}

fn snapshot(shared: &Arc<Shared>) -> State {
    let state = shared.state.lock().expect("state poisoned");
    State {
        windows: state.windows.clone(),
        workspaces: state.workspaces.clone(),
        outputs: state.outputs.clone(),
        empty_named_since: HashMap::new(),
    }
}

fn focused_workspace(workspaces: &[Workspace]) -> Option<&Workspace> {
    workspaces
        .iter()
        .find(|workspace| workspace.is_focused)
        .or_else(|| workspaces.iter().find(|workspace| workspace.is_active))
}

fn focused_workspace_reference(workspaces: &[Workspace]) -> Option<WorkspaceReferenceArg> {
    let workspace = focused_workspace(workspaces)?;
    Some(
        workspace
            .name
            .as_ref()
            .map(|name| WorkspaceReferenceArg::Name(name.clone()))
            .unwrap_or(WorkspaceReferenceArg::Index(workspace.idx)),
    )
}

fn workspace_by_name<'a>(workspaces: &'a [Workspace], name: &str) -> Option<&'a Workspace> {
    workspaces
        .iter()
        .find(|workspace| workspace.name.as_deref() == Some(name))
}

fn tiled_windows_for_workspace(windows: &[Window], workspace_id: u64) -> Vec<Window> {
    windows
        .iter()
        .filter(|window| window.workspace_id == Some(workspace_id) && !window.is_floating)
        .cloned()
        .collect()
}

fn all_windows_for_workspace(windows: &[Window], workspace_id: u64) -> Vec<Window> {
    windows
        .iter()
        .filter(|window| window.workspace_id == Some(workspace_id))
        .cloned()
        .collect()
}

fn companion_socket_path() -> Result<PathBuf, String> {
    let runtime_dir = env::var_os("XDG_RUNTIME_DIR")
        .ok_or("XDG_RUNTIME_DIR is not set; cannot determine companion socket path")?;
    Ok(PathBuf::from(runtime_dir).join("niri-companion.sock"))
}
