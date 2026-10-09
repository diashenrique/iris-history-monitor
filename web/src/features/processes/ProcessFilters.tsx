import { useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '../../design/components';
import type { ProcessQuery } from '../../lib/url-state';

// Filters of the process list (FR-011): exact namespace, user and state, and a text search of at most
// 100 characters, applied together.

type Filters = Pick<ProcessQuery, 'namespace' | 'user' | 'state' | 'q'>;

export function ProcessFilters({ value, onApply }: { value: Filters; onApply: (f: Filters) => void }) {
  const { t } = useTranslation();
  const [draft, setDraft] = useState<Filters>(value);
  const ids = { namespace: useId(), user: useId(), state: useId(), q: useId() };
  const input = 'min-h-9 w-full rounded-lg border border-control bg-surface px-3 text-text hover:border-text';

  function submit(e: FormEvent) {
    e.preventDefault();
    onApply({ namespace: draft.namespace.trim(), user: draft.user.trim(), state: draft.state.trim(), q: draft.q.trim() });
  }

  const field = (key: keyof Filters, label: string, max: number) => (
    <span className="grid gap-1">
      <label htmlFor={ids[key]} className="text-sm text-muted">
        {label}
      </label>
      <input
        id={ids[key]}
        className={input}
        maxLength={max}
        value={draft[key]}
        onChange={(e) => setDraft({ ...draft, [key]: e.target.value })}
      />
    </span>
  );

  return (
    <form onSubmit={submit} aria-label={t('processes.filters')} className="grid grid-cols-[repeat(auto-fit,minmax(min(160px,100%),1fr))] items-end gap-3">
      {field('namespace', t('processes.namespace'), 128)}
      {field('user', t('processes.user'), 128)}
      {field('state', t('processes.state'), 128)}
      {field('q', t('processes.search'), 100)}
      <div className="flex gap-2">
        <Button type="submit" className="bg-accent text-on-accent border-accent">
          {t('processes.apply')}
        </Button>
        <Button
          onClick={() => {
            const empty = { namespace: '', user: '', state: '', q: '' };
            setDraft(empty);
            onApply(empty);
          }}
        >
          {t('processes.clear')}
        </Button>
      </div>
    </form>
  );
}
