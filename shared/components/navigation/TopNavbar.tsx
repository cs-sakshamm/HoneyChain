import React from 'react';
import { Plus, MessageSquare } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';

export interface TopNavbarProps {
  logoText?: string;
  hasUnreadInbox?: boolean;
  onCreateClick?: () => void;
  onInboxClick?: () => void;
  className?: string;
}

/**
 * Pinterest-inspired Top Navigation Bar
 * - Sticky/fixed at top with z-index 50 and padding (12px 16px)
 * - Left: Custom text logo (<span className="logo-text">YOUR_LOGO_TEXT</span>)
 * - Right: Plus (+) creation button and Message/Chat inbox button with red notification dot
 */
export const TopNavbar: React.FC<TopNavbarProps> = ({
  logoText = 'YOUR_LOGO_TEXT',
  hasUnreadInbox = true,
  onCreateClick,
  onInboxClick,
  className = '',
}) => {
  const navigate = useNavigate();

  const handleCreate = () => {
    if (onCreateClick) {
      onCreateClick();
    } else {
      navigate('/create');
    }
  };

  const handleInbox = () => {
    if (onInboxClick) {
      onInboxClick();
    } else {
      navigate('/inbox');
    }
  };

  return (
    <header className={`top-navbar ${className}`}>
      <div className="top-navbar-container">
        {/* Left Section: Custom Text Logo */}
        <Link to="/" className="logo-link" aria-label="Go to Home">
          <span className="logo-text">{logoText}</span>
        </Link>

        {/* Right Section: Add and Inbox Actions */}
        <div className="top-navbar-actions">
          {/* Add / Create Button */}
          <button
            type="button"
            onClick={handleCreate}
            aria-label="Create new item"
            className="nav-icon-btn"
          >
            <Plus className="w-5 h-5 stroke-[2.2]" />
          </button>

          {/* Inbox / Messages Button */}
          <button
            type="button"
            onClick={handleInbox}
            aria-label="Inbox and messages"
            className="nav-icon-btn"
          >
            <MessageSquare className="w-5 h-5 stroke-[2.2]" />
            {hasUnreadInbox && <span className="notification-dot" aria-hidden="true" />}
          </button>
        </div>
      </div>
    </header>
  );
};

export default TopNavbar;
