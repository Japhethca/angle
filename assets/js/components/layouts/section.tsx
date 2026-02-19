import { cn } from "@/lib/utils";

interface SectionProps {
  children: React.ReactNode;
  fullBleed?: boolean;
  constrain?: boolean;
  maxWidth?: 'max-w-sm' | 'max-w-md' | 'max-w-lg' | 'max-w-xl' | 'max-w-2xl' | 'max-w-3xl' | 'max-w-4xl' | 'max-w-5xl' | 'max-w-6xl' | 'max-w-7xl' | 'max-w-full';
  background?: 'default' | 'muted' | 'dark' | 'gradient' | 'accent';
  className?: string;
  id?: string;
  as?: 'section' | 'div' | 'footer';
}

const BG_CLASSES = {
  default: '',
  muted: 'bg-surface-muted',
  dark: 'bg-content text-background dark:bg-surface-muted dark:text-content',
  gradient: 'bg-gradient-to-br from-primary-600 to-primary-1000',
  accent: 'bg-primary-50 dark:bg-primary-950/30',
} as const;

export function Section({
  children,
  fullBleed = false,
  constrain = true,
  maxWidth = 'max-w-7xl',
  background = 'default',
  className = '',
  id,
  as: Component = 'section',
}: SectionProps) {
  if (fullBleed) {
    return (
      <Component id={id} className={cn(BG_CLASSES[background], className)}>
        <div className={cn('mx-auto px-4 lg:px-10', maxWidth)}>
          {children}
        </div>
      </Component>
    );
  }

  if (constrain) {
    return (
      <Component
        id={id}
        className={cn('mx-auto px-4 lg:px-10', maxWidth, BG_CLASSES[background], className)}
      >
        {children}
      </Component>
    );
  }

  return (
    <Component id={id} className={cn(BG_CLASSES[background], className)}>
      {children}
    </Component>
  );
}
