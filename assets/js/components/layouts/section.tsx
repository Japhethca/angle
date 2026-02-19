interface SectionProps {
  children: React.ReactNode;
  fullBleed?: boolean;
  constrain?: boolean;
  maxWidth?: string;
  background?: 'default' | 'muted' | 'dark' | 'gradient' | 'accent';
  className?: string;
  id?: string;
  as?: 'section' | 'div';
}

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
  const bgClasses = {
    default: '',
    muted: 'bg-surface-muted',
    dark: 'bg-content text-background dark:bg-surface-muted dark:text-content',
    gradient: 'bg-gradient-to-br from-primary-600 to-primary-1000',
    accent: 'bg-primary-50 dark:bg-primary-950/30',
  };

  if (fullBleed) {
    return (
      <Component id={id} className={`${bgClasses[background]} ${className}`}>
        <div className={`mx-auto ${maxWidth} px-4 lg:px-10`}>
          {children}
        </div>
      </Component>
    );
  }

  if (constrain) {
    return (
      <Component
        id={id}
        className={`mx-auto ${maxWidth} px-4 lg:px-10 ${bgClasses[background]} ${className}`}
      >
        {children}
      </Component>
    );
  }

  return (
    <Component id={id} className={`${bgClasses[background]} ${className}`}>
      {children}
    </Component>
  );
}
