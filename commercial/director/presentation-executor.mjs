import { planPresentation } from './presentation-plan.mjs';
import { setTimeout as delay } from 'node:timers/promises';

// Adapter must acknowledge confirmed output, not merely HTTP receipt.
// No automatic retries: ambiguous effects require manual reconciliation.
export class PresentationExecutor {
  #active = null;
  #seen = new Set();
  #blocked = false;
  constructor({ showGraphic, returnProgram, wait = delay, maxCues = 4096 } = {}) {
    if (![showGraphic, returnProgram, wait].every(fn => typeof fn === 'function')) throw new Error('ADAPTER_REQUIRED');
    if (!Number.isSafeInteger(maxCues) || maxCues < 1) throw new Error('INVALID_CAPACITY');
    this.showGraphic = showGraphic; this.returnProgram = returnProgram;
    this.wait = wait; this.maxCues = maxCues;
  }
  get status() { return { active: this.#active?.id ?? null, blocked: this.#blocked }; }
  cancel() { if (!this.#active) return false; this.#active.controller.abort(); return true; }
  // Only call after operator confirms actual program output and no pending adapter effects.
  acknowledgeManualRecovery() {
    if (this.#active) throw new Error('DIRECTOR_BUSY');
    this.#blocked = false;
  }
  async play(request) {
    const plan = planPresentation(request);
    if (this.#seen.has(plan.cueId)) return { status:'duplicate' };
    if (this.#blocked) throw new Error('MANUAL_RECOVERY_REQUIRED');
    if (this.#active) throw new Error('DIRECTOR_BUSY');
    if (this.#seen.size >= this.maxCues) throw new Error('CUE_HISTORY_FULL');
    const controller = new AbortController();
    const signal = controller.signal;
    this.#seen.add(plan.cueId);
    this.#active = { id:plan.cueId, controller };
    try {
      for (const step of plan.steps) {
        signal.throwIfAborted();
        const confirmed = step.action === 'SHOW_GRAPHIC'
          ? await this.showGraphic(step.graphic, { cueId:plan.cueId, signal })
          : await this.returnProgram(step.input, { cueId:plan.cueId, signal });
        signal.throwIfAborted();
        if (confirmed !== true) throw new Error('OUTPUT_NOT_CONFIRMED');
        if (step.action === 'SHOW_GRAPHIC') await this.wait(step.durationMs, undefined, { signal });
      }
      return { status:'completed' };
    } catch (error) {
      // Manual takeover must never be overwritten by an automatic return.
      this.#blocked = true;
      return { status:signal.aborted ? 'cancelled' : 'uncertain', manualRecoveryRequired:true };
    } finally { this.#active = null; }
  }
}
