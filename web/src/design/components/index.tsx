import type { ButtonHTMLAttributes, ReactNode, SelectHTMLAttributes } from 'react';
import { useEffect, useId, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import type { Status } from '../../api/types';

// Base components following the approved mock-up (research R10). Native elements where they are already
// accessible (button, select, dialog).

const control =
  'min-h-9 rounded-lg border border-control bg-surface px-3 text-text hover:border-text disabled:opacity-60';

export function Button({ className = '', ...props }: ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button type="button" className={`${control} cursor-pointer font-medium ${className}`} {...props} />;
}

/** A button that stays pressed, such as Pause (aria-pressed). */
export function ToggleButton({
  pressed,
  onPressedChange,
  children,
  ...props
}: Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'onChange'> & {
  pressed: boolean;
  onPressedChange: (pressed: boolean) => void;
}) {
  return (
    <Button aria-pressed={pressed} onClick={() => onPressedChange(!pressed)} {...props}>
      {children}
    </Button>
  );
}

/** A labelled native select; the label can be visually hidden. */
export function Select({
  label,
  hideLabel = false,
  children,
  className = '',
  ...props
}: SelectHTMLAttributes<HTMLSelectElement> & { label: string; hideLabel?: boolean; children: ReactNode }) {
  const id = useId();
  return (
    <span className="inline-flex items-center gap-2">
      <label htmlFor={id} className={hideLabel ? 'sr-only' : 'text-sm text-muted'}>
        {label}
      </label>
      <select id={id} className={`${control} ${className}`} {...props}>
        {children}
      </select>
    </span>
  );
}

const statusStyle: Record<Status, string> = {
  ok: 'text-ok',
  warning: 'text-warning',
  critical: 'text-critical',
  unavailable: 'text-unavailable',
};

export function StatusIcon({ status, size = 14 }: { status: Status; size?: number }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', 'aria-hidden': true } as const;
  switch (status) {
    case 'ok':
      return (
        <svg {...common}>
          <path d="m5 12.5 4.5 4.5L19 7.5" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'warning':
      return (
        <svg {...common}>
          <path d="M12 3 2 21h20L12 3Z" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round" />
          <path d="M12 10v4.5M12 17.5h.01" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
        </svg>
      );
    case 'critical':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2.4" />
          <path d="m8.5 8.5 7 7m0-7-7 7" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
        </svg>
      );
    default:
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2.4" strokeDasharray="3 3" />
        </svg>
      );
  }
}

/** Status as icon + label + colour, never colour alone (FR-004). */
export function StatusBadge({ status }: { status: Status }) {
  const { t } = useTranslation();
  return (
    <span className={`inline-flex items-center gap-1.5 text-[0.8125rem] font-semibold ${statusStyle[status]}`}>
      <StatusIcon status={status} />
      {t(`status.${status}`)}
    </span>
  );
}

/**
 * A modal dialog on the native <dialog> element: showModal() makes the rest of the page inert, keeps focus
 * inside and closes on Escape. No library injects <style> elements, so the interface runs under a strict
 * Content-Security-Policy (style-src 'self'); index.css locks the page scroll while a dialog is open.
 */
export function Dialog({
  open,
  onOpenChange,
  title,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  children: ReactNode;
}) {
  const { t } = useTranslation();
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (!open || !dialog) return;
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    if (!dialog.open) dialog.showModal();
    return () => {
      if (dialog.open) dialog.close();
      // Focus goes back to what opened the dialog, also when React removes the dialog without close().
      if (opener?.isConnected) opener.focus();
    };
  }, [open]);

  if (!open) return null;
  return (
    // The backdrop click is a pointer convenience; from the keyboard, Escape and the close button close it.
    // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-noninteractive-element-interactions
    <dialog
      ref={ref}
      aria-labelledby={titleId}
      onCancel={(event) => {
        // Escape: React owns the open state, so the dialog closes by being removed.
        event.preventDefault();
        onOpenChange(false);
      }}
      onClick={(event) => {
        // A click on the backdrop lands on the <dialog> itself (the content is the inner div).
        if (event.target === event.currentTarget) onOpenChange(false);
      }}
      className="mx-auto mt-[10vh] max-h-[80vh] w-[calc(100%-2rem)] max-w-2xl overflow-auto rounded-xl border border-divider bg-raised p-0 text-text shadow-xl backdrop:bg-black/40"
    >
      <div className="p-5">
        <div className="mb-3 flex items-start justify-between gap-4">
          <h2 id={titleId} className="m-0 text-lg font-semibold">
            {title}
          </h2>
          <button type="button" className={`${control} cursor-pointer`} aria-label={t('common.close')} onClick={() => onOpenChange(false)}>
            ×
          </button>
        </div>
        {children}
      </div>
    </dialog>
  );
}
