export const MATCH_SCHEMA_VERSION = 1;

const SIDES = new Set(["HOME", "AWAY"]);
const PERIODS = new Set(["PRE", "1H", "HT", "2H", "ET1", "ET_BREAK", "ET2", "PEN", "FT"]);
const EVENT_COMMANDS = new Set(["GOAL", "YELLOW", "RED", "SUB", "HALF_TIME", "FULL_TIME", "MVP"]);

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function asNonNegativeInt(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.trunc(n));
}

function requiredString(value, field) {
  const s = String(value ?? "").trim();
  if (!s) throw new Error(`INVALID_${field.toUpperCase()}`);
  return s;
}

function normalizePlayer(player) {
  if (!player || typeof player !== "object") return null;
  return {
    id: String(player.id ?? "").trim(),
    name: String(player.name ?? "").trim(),
    number: String(player.number ?? "").trim(),
  };
}

function normalizeMeta(meta = {}) {
  return {
    fixtureId: requiredString(meta.fixtureId, "fixtureId"),
    competition: String(meta.competition ?? "").trim(),
    home: requiredString(meta.home, "home"),
    away: requiredString(meta.away, "away"),
  };
}

export function createInitialMatchState(meta) {
  const m = normalizeMeta(meta);
  return {
    schemaVersion: MATCH_SCHEMA_VERSION,
    fixtureId: m.fixtureId,
    competition: m.competition,
    home: m.home,
    away: m.away,
    revision: 0,
    sequence: 0,
    period: "PRE",
    homeScore: 0,
    awayScore: 0,
    homeRedCards: 0,
    awayRedCards: 0,
    scoreboardVisible: false,
    scoreboardFrozen: false,
    clock: {
      running: false,
      elapsedSeconds: 0,
    },
    penalties: {
      started: false,
      finished: false,
      home: 0,
      away: 0,
      history: [],
    },
    eventLog: [],
    replayMarkers: [],
    processedCommandIds: [],
    lastEvent: null,
    updatedAt: new Date(0).toISOString(),
  };
}

export function hydrateMatchState(raw) {
  if (!raw || typeof raw !== "object") throw new Error("INVALID_MATCH_STATE");
  const base = createInitialMatchState({
    fixtureId: raw.fixtureId,
    competition: raw.competition,
    home: raw.home,
    away: raw.away,
  });

  const next = {
    ...base,
    ...clone(raw),
    schemaVersion: MATCH_SCHEMA_VERSION,
    revision: asNonNegativeInt(raw.revision),
    sequence: asNonNegativeInt(raw.sequence),
    homeScore: asNonNegativeInt(raw.homeScore),
    awayScore: asNonNegativeInt(raw.awayScore),
    homeRedCards: asNonNegativeInt(raw.homeRedCards),
    awayRedCards: asNonNegativeInt(raw.awayRedCards),
    eventLog: Array.isArray(raw.eventLog) ? clone(raw.eventLog) : [],
    replayMarkers: Array.isArray(raw.replayMarkers) ? clone(raw.replayMarkers) : [],
    processedCommandIds: Array.isArray(raw.processedCommandIds)
      ? raw.processedCommandIds.map(String).filter(Boolean)
      : [],
  };

  if (!PERIODS.has(next.period)) next.period = "PRE";
  next.clock = {
    running: !!raw.clock?.running,
    elapsedSeconds: asNonNegativeInt(raw.clock?.elapsedSeconds),
  };
  next.penalties = {
    started: !!raw.penalties?.started,
    finished: !!raw.penalties?.finished,
    home: asNonNegativeInt(raw.penalties?.home),
    away: asNonNegativeInt(raw.penalties?.away),
    history: Array.isArray(raw.penalties?.history) ? clone(raw.penalties.history) : [],
  };
  next.scoreboardVisible = !!raw.scoreboardVisible;
  next.scoreboardFrozen = !!raw.scoreboardFrozen;
  return next;
}

function assertCommand(command) {
  if (!command || typeof command !== "object") throw new Error("INVALID_COMMAND");
  const commandId = requiredString(command.commandId, "commandId");
  const type = requiredString(command.type, "type").toUpperCase();
  return { commandId, type };
}

function assertSide(side) {
  const s = String(side ?? "").toUpperCase();
  if (!SIDES.has(s)) throw new Error("INVALID_SIDE");
  return s;
}

function makeEvent(state, command, type, extra = {}) {
  const nextSequence = state.sequence + 1;
  return {
    eventId: `${state.fixtureId}:${nextSequence}`,
    sequence: nextSequence,
    commandId: String(command.commandId),
    type,
    at: String(command.at ?? "").trim(),
    createdAt: String(command.createdAt ?? new Date().toISOString()),
    ...extra,
  };
}

function recordEvent(state, event) {
  state.sequence = event.sequence;
  state.eventLog.push(event);
  state.lastEvent = event;

  if (event.type === "GOAL" || event.type === "RED") {
    state.replayMarkers.push({
      eventId: event.eventId,
      type: event.type,
      side: event.side,
      at: event.at,
      createdAt: event.createdAt,
    });
  }
}

function applyEventCommand(state, command, type) {
  let side = null;
  if (["GOAL", "YELLOW", "RED", "SUB"].includes(type)) side = assertSide(command.side);

  const extra = {
    side,
    player: normalizePlayer(command.player),
  };

  if (type === "SUB") {
    extra.off = normalizePlayer(command.off);
    extra.on = normalizePlayer(command.on);
  }

  if (type === "GOAL") {
    if (side === "HOME") state.homeScore += 1;
    else state.awayScore += 1;
  }

  if (type === "RED") {
    if (side === "HOME") state.homeRedCards += 1;
    else state.awayRedCards += 1;
  }

  if (type === "HALF_TIME") {
    state.period = "HT";
    state.clock.running = false;
  }
  if (type === "FULL_TIME") {
    state.period = "FT";
    state.clock.running = false;
  }

  const event = makeEvent(state, command, type, extra);
  recordEvent(state, event);
  return event;
}

export function applyCommand(currentState, command) {
  const { commandId, type } = assertCommand(command);
  const current = hydrateMatchState(currentState);

  if (current.processedCommandIds.includes(commandId)) {
    return { state: current, event: null, duplicate: true };
  }

  const state = clone(current);
  let event = null;

  if (EVENT_COMMANDS.has(type)) {
    event = applyEventCommand(state, command, type);
  } else if (type === "SCORE_ADJUST") {
    const side = assertSide(command.side);
    const delta = command.delta;
    if (!Number.isSafeInteger(delta) || Math.abs(delta) > 100) throw new Error("INVALID_SCORE_DELTA");
    const key = side === "HOME" ? "homeScore" : "awayScore";
    const before = state[key];
    const after = Math.max(0, before + delta);
    if (!Number.isSafeInteger(after)) throw new Error("INVALID_SCORE_DELTA");
    state[key] = after;
    event = makeEvent(state, command, "SCORE_ADJUST", { side, requestedDelta: delta, appliedDelta: after - before, before, after });
    recordEvent(state, event);
  } else if (type === "SET_PERIOD") {
    const period = String(command.period ?? "").toUpperCase();
    if (!PERIODS.has(period)) throw new Error("INVALID_PERIOD");
    state.period = period;
    if (["PRE", "HT", "ET_BREAK", "PEN", "FT"].includes(period)) state.clock.running = false;
  } else if (type === "SET_CLOCK_RUNNING") {
    if (typeof command.running !== "boolean" || "elapsedSeconds" in command) throw new Error("INVALID_CLOCK");
    if (command.running && !["1H", "2H", "ET1", "ET2"].includes(state.period)) throw new Error("INVALID_CLOCK_PERIOD");
    state.clock.running = command.running;
  } else if (type === "SET_CLOCK") {
    if (typeof command.running !== "boolean" || !Number.isSafeInteger(command.elapsedSeconds) || command.elapsedSeconds < 0) throw new Error("INVALID_CLOCK");
    state.clock = {
      running: command.running,
      elapsedSeconds: command.elapsedSeconds,
    };
  } else if (type === "SET_SCOREBOARD") {
    if ("visible" in command) state.scoreboardVisible = !!command.visible;
    if ("frozen" in command) state.scoreboardFrozen = !!command.frozen;
  } else if (type === "START_PENALTIES") {
    if (state.penalties.started || state.penalties.finished || state.period === "FT") throw new Error("INVALID_PENALTY_LIFECYCLE");
    state.period = "PEN";
    state.clock.running = false;
    state.penalties.started = true;
    state.penalties.finished = false;
  } else if (type === "PENALTY_ATTEMPT") {
    if (state.period !== "PEN" || !state.penalties.started || state.penalties.finished) throw new Error("INVALID_PENALTY_LIFECYCLE");
    const side = assertSide(command.side);
    const outcome = String(command.outcome ?? "").toUpperCase();
    if (!["SCORED", "MISSED"].includes(outcome)) throw new Error("INVALID_PENALTY_OUTCOME");
    state.period = "PEN";
    state.clock.running = false;
    state.penalties.started = true;
    state.penalties.finished = false;
    if (outcome === "SCORED") {
      if (side === "HOME") state.penalties.home += 1;
      else state.penalties.away += 1;
    }
    const attempt = {
      attemptId: `${state.fixtureId}:pen:${state.sequence + 1}`,
      commandId,
      side,
      outcome,
      player: normalizePlayer(command.player),
      createdAt: String(command.createdAt ?? new Date().toISOString()),
    };
    state.penalties.history.push(attempt);
    event = makeEvent(state, command, "PENALTY_ATTEMPT", {
      side,
      outcome,
      player: attempt.player,
      attemptId: attempt.attemptId,
    });
    recordEvent(state, event);
  } else if (type === "UNDO_PENALTY_ATTEMPT") {
    if (state.period !== "PEN" || !state.penalties.started || state.penalties.finished) throw new Error("INVALID_PENALTY_LIFECYCLE");
    const attemptId = requiredString(command.attemptId, "attemptId");
    const attempt = state.penalties.history.at(-1);
    if (!attempt || attempt.attemptId !== attemptId) throw new Error("INVALID_PENALTY_ATTEMPT_TARGET");
    if (!SIDES.has(attempt.side) || !["SCORED", "MISSED"].includes(attempt.outcome)) throw new Error("INVALID_PENALTY_HISTORY");
    const key = attempt.side === "HOME" ? "home" : "away";
    if (attempt.outcome === "SCORED") {
      if (state.penalties[key] < 1) throw new Error("INVALID_PENALTY_HISTORY");
      state.penalties[key] -= 1;
    }
    state.penalties.history.pop();
    event = makeEvent(state, command, "UNDO_PENALTY_ATTEMPT", { attemptId, side: attempt.side, outcome: attempt.outcome });
    recordEvent(state, event);
  } else if (type === "FINISH_PENALTIES") {
    if (state.period !== "PEN" || !state.penalties.started || state.penalties.finished) throw new Error("INVALID_PENALTY_LIFECYCLE");
    state.penalties.started = true;
    state.penalties.finished = true;
    state.period = "FT";
    state.clock.running = false;
  } else if (type === "CLEAR_EVENT") {
    state.lastEvent = null;
  } else {
    throw new Error("UNSUPPORTED_COMMAND");
  }

  state.revision += 1;
  state.processedCommandIds.push(commandId);
  state.updatedAt = String(command.createdAt ?? new Date().toISOString());

  return { state: hydrateMatchState(state), event, duplicate: false };
}

export function consistencyView(stateLike) {
  const s = hydrateMatchState(stateLike);
  return JSON.stringify({
    fixtureId: s.fixtureId,
    revision: s.revision,
    sequence: s.sequence,
    period: s.period,
    homeScore: s.homeScore,
    awayScore: s.awayScore,
    homeRedCards: s.homeRedCards,
    awayRedCards: s.awayRedCards,
    scoreboardVisible: s.scoreboardVisible,
    scoreboardFrozen: s.scoreboardFrozen,
    clock: s.clock,
    penalties: {
      started: s.penalties.started,
      finished: s.penalties.finished,
      home: s.penalties.home,
      away: s.penalties.away,
      historyCount: s.penalties.history.length,
    },
  });
}
