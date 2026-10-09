import { render, screen } from '@testing-library/react';
import { App } from '../../src/App';
import { expectNoSeriousAxeIssues } from '../axe';

describe('App scaffold', () => {
  it('renders a main landmark with a heading and no serious accessibility issue', async () => {
    const { container } = render(<App />);
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
    await expectNoSeriousAxeIssues(container);
  });
});
