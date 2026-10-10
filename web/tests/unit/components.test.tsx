import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { Button, Dialog, Select, StatusBadge, ToggleButton } from '../../src/design/components';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';

describe('base components', () => {
  it('StatusBadge shows an icon and a text label for every status (FR-004)', async () => {
    const { container } = render(
      <div>
        <StatusBadge status="ok" />
        <StatusBadge status="warning" />
        <StatusBadge status="critical" />
        <StatusBadge status="unavailable" />
      </div>,
    );
    for (const label of ['OK', 'Warning', 'Critical', 'Unavailable']) expect(screen.getByText(label)).toBeInTheDocument();
    expect(container.querySelectorAll('svg[aria-hidden="true"]')).toHaveLength(4);
    await expectNoSeriousAxeIssues(container);
  });

  it('Select is labelled, even with a hidden label', async () => {
    const { container } = render(
      <Select label="Language" hideLabel defaultValue="en">
        <option value="en">English</option>
      </Select>,
    );
    expect(screen.getByLabelText('Language')).toHaveValue('en');
    await expectNoSeriousAxeIssues(container);
  });

  it('ToggleButton reports its pressed state', async () => {
    function Harness() {
      const [p, setP] = useState(false);
      return (
        <ToggleButton pressed={p} onPressedChange={setP}>
          Pause
        </ToggleButton>
      );
    }
    const { container } = render(<Harness />);
    const button = screen.getByRole('button', { name: 'Pause' });
    expect(button).toHaveAttribute('aria-pressed', 'false');
    await userEvent.click(button);
    expect(button).toHaveAttribute('aria-pressed', 'true');
    await expectNoSeriousAxeIssues(container);
  });

  it('Button is a button', () => {
    render(<Button>Retry</Button>);
    expect(screen.getByRole('button', { name: 'Retry' })).toHaveAttribute('type', 'button');
  });

  it('Dialog has a title, traps focus and closes with Escape', async () => {
    function Harness() {
      const [open, setOpen] = useState(true);
      return (
        <Dialog open={open} onOpenChange={setOpen} title="Process 4285">
          <p>Details</p>
        </Dialog>
      );
    }
    render(<Harness />);
    const dialog = screen.getByRole('dialog', { name: 'Process 4285' });
    expect(dialog).toBeInTheDocument();
    await expectNoSeriousAxeIssues(dialog);
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('Dialog gives focus back to what opened it, and the close button closes it', async () => {
    function Harness() {
      const [open, setOpen] = useState(false);
      return (
        <>
          <button onClick={() => setOpen(true)}>Open</button>
          <Dialog open={open} onOpenChange={setOpen} title="Process 4285">
            <p>Details</p>
          </Dialog>
        </>
      );
    }
    render(<Harness />);
    const opener = screen.getByRole('button', { name: 'Open' });
    await userEvent.click(opener);
    await userEvent.click(screen.getByRole('button', { name: 'Close' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(opener).toHaveFocus();
  });
});
