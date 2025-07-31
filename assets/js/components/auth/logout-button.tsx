import { router } from '@inertiajs/react';
import { Button } from '../ui/button';

interface LogoutButtonProps {
  className?: string;
  children?: React.ReactNode;
}

export function LogoutButton({ className, children = "Logout" }: LogoutButtonProps) {
  const handleLogout = () => {
    router.post('/auth/logout');
  };

  return (
    <Button 
      onClick={handleLogout}
      variant="outline"
      className={className}
    >
      {children}
    </Button>
  );
}