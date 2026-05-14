import type { CSSProperties } from 'react';

const styles: Record<'shell' | 'poster', CSSProperties> = {
  shell: {
    border: '1px dashed var(--border)',
    borderRadius: '0.85rem',
    padding: '1rem',
    background: 'var(--surface-muted)',
  },
  poster: {
    margin: 0,
    color: 'var(--text-muted)',
  },
};

export default function PlaceholderDemo() {
  return (
    <div style={styles.shell}>
      <p style={styles.poster}>TODO: replace this placeholder with an interactive demo component.</p>
    </div>
  );
}
