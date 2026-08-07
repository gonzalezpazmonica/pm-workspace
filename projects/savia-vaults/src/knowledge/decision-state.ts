/* Decision state management for SaviaVaults (SE-309).
 *
 * Patron "promote" adoptado de session memory: la ultima marca gana, nada se
 * borra. Cada cambio de estado queda en el historial con razon y fecha.
 */

import { DecisionRecord, DecisionState } from './decision.js';

export interface StateChange {
  from: DecisionState;
  to: DecisionState;
  reason: string;
  by: string;
  at: string;
}

export interface DecisionStateLog {
  record: DecisionRecord;
  history: StateChange[];
}

export function promote(
  record: DecisionRecord,
  state: DecisionState,
  reason: string,
  by: string,
  history: StateChange[] = [],
): DecisionStateLog {
  const now = new Date().toISOString();
  const change: StateChange = {
    from: record.state,
    to: state,
    reason,
    by,
    at: now,
  };
  const updated: DecisionRecord = {
    ...record,
    state,
    state_reason: reason,
    updated_at: now,
  };
  return {
    record: updated,
    history: [...history, change],
  };
}

export function getActiveState(log: DecisionStateLog): DecisionRecord {
  return log.record;
}
