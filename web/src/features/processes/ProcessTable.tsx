import { createColumnHelper, flexRender, getCoreRowModel, useReactTable } from '@tanstack/react-table';
import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { Process } from '../../api/types';
import { formatNumber } from '../../i18n/format';

// The process table (FR-011) with TanStack Table in manual mode: the API sorts and pages, the table only
// shows. Column headers are buttons that set the sort; aria-sort says which column sorts and how. Wide
// tables scroll inside their own focusable region on narrow screens.

export const COLUMNS = ['pid', 'username', 'namespace', 'routine', 'state', 'cpuTime', 'commands', 'globals', 'elapsedTime'] as const;

const helper = createColumnHelper<Process>();

export function ProcessTable({
  items,
  sort,
  onSort,
  onOpen,
}: {
  items: Process[];
  sort: string;
  onSort: (sort: string) => void;
  onOpen: (pid: string) => void;
}) {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const field = sort.startsWith('-') ? sort.slice(1) : sort;
  const descending = sort.startsWith('-');

  const columns = useMemo(
    () =>
      COLUMNS.map((name) =>
        helper.accessor((row) => row[name], {
          id: name,
          header: () => t(`processes.fields.${name}`),
          cell: (info) => {
            const v = info.getValue();
            if (name === 'pid')
              return (
                <button
                  type="button"
                  className="cursor-pointer font-semibold text-accent underline-offset-2 hover:underline"
                  aria-label={t('processes.details', { pid: v })}
                  onClick={() => onOpen(String(v))}
                >
                  {v}
                </button>
              );
            return typeof v === 'number' ? formatNumber(v, lang) : (v ?? '');
          },
        }),
      ),
    [t, lang, onOpen],
  );

  const table = useReactTable({ data: items, columns, getCoreRowModel: getCoreRowModel(), manualSorting: true, manualPagination: true });

  return (
    // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
    <div tabIndex={0} role="region" aria-label={t('processes.tableLabel')} className="overflow-x-auto rounded-[10px] border border-divider bg-surface">
      <table className="w-full border-collapse text-sm tabular-nums">
        <thead>
          {table.getHeaderGroups().map((group) => (
            <tr key={group.id} className="border-b border-divider text-left text-muted">
              {group.headers.map((header) => {
                const active = header.id === field;
                const numeric = ['pid', 'cpuTime', 'commands', 'globals'].includes(header.id);
                return (
                  <th
                    key={header.id}
                    scope="col"
                    aria-sort={active ? (descending ? 'descending' : 'ascending') : 'none'}
                    className={`whitespace-nowrap px-3 py-2 font-semibold ${numeric ? 'text-right' : ''}`}
                  >
                    <button
                      type="button"
                      className={`inline-flex cursor-pointer items-center gap-1 ${active ? 'text-text' : ''}`}
                      onClick={() => onSort(active && !descending ? `-${header.id}` : header.id)}
                    >
                      {flexRender(header.column.columnDef.header, header.getContext())}
                      <span aria-hidden="true">{active ? (descending ? '▼' : '▲') : ''}</span>
                    </button>
                  </th>
                );
              })}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => (
            <tr key={row.id} data-pid={String(row.original.pid)} className="border-b border-divider last:border-b-0">
              {row.getVisibleCells().map((cell) => {
                const numeric = ['pid', 'cpuTime', 'commands', 'globals'].includes(cell.column.id);
                return (
                  <td key={cell.id} className={`whitespace-nowrap px-3 py-1.5 ${numeric ? 'text-right' : ''}`}>
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
