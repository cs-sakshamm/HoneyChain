import React from 'react';
import { Home, Search, ArrowLeftRight, User } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

export interface NavItemConfig {
  id: string;
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  ariaLabel: string;
}

export interface BottomNavbarProps {
  items?: NavItemConfig[];
  className?: string;
}

const DEFAULT_NAV_ITEMS: NavItemConfig[] = [
  { id: 'home', label: 'Home', href: '/', icon: Home, ariaLabel: 'Home feed' },
  { id: 'search', label: 'Search', href: '/search', icon: Search, ariaLabel: 'Search' },
  { id: 'exchange', label: 'Exchange History', href: '/exchange-history', icon: ArrowLeftRight, ariaLabel: 'Exchange history' },
  { id: 'profile', label: 'Profile', href: '/profile', icon: User, ariaLabel: 'Your profile' },
];

/**
 * Pinterest-inspired Floating Bottom Pill Dock
 * - Centered floating dock positioned 16px above bottom screen edge
 * - Dark frosted glass appearance (rgba(30, 30, 30, 0.8) + blur(12px))
 * - 4 Core Navigation Items: Home, Search, Exchange History, Profile
 * - Minimum 44x44px touch targets and smooth active states
 */
export const BottomNavbar: React.FC<BottomNavbarProps> = ({
  items = DEFAULT_NAV_ITEMS,
  className = '',
}) => {
  const location = useLocation();
  const currentPath = location.pathname;

  return (
    <nav aria-label="Main Bottom Navigation" className={`bottom-dock-wrapper ${className}`}>
      <div className="bottom-dock">
        {items.map((item) => {
          const Icon = item.icon;
          const isActive =
            item.href === '/'
              ? currentPath === '/'
              : currentPath.startsWith(item.href);

          return (
            <Link
              key={item.id}
              to={item.href}
              aria-label={item.ariaLabel}
              aria-current={isActive ? 'page' : undefined}
              className={`dock-item ${isActive ? 'active' : ''}`}
            >
              <Icon className="w-5 h-5" />
            </Link>
          );
        })}
      </div>
    </nav>
  );
};

export default BottomNavbar;
