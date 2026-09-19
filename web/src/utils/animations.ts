import { Variants } from 'framer-motion';

export const pageVariants: Variants = {
  hidden: { opacity: 0, y: 10 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.25, ease: 'easeOut' } },
  exit: { opacity: 0, y: -10, transition: { duration: 0.2, ease: 'easeIn' } },
};

export const staggerContainer: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.05,
    },
  },
};

export const cardVariants: Variants = {
  hidden: { opacity: 0, y: 10 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.2, ease: 'easeOut' } },
};

export const hoverCardProps = {
  whileHover: { scale: 1.02, transition: { duration: 0.15 } },
  whileTap: { scale: 0.99 },
};

export const buttonProps = {
  whileHover: { scale: 1.02, transition: { duration: 0.15 } },
  whileTap: { scale: 0.97 },
};

export const reducedPageVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { duration: 0.25 } },
  exit: { opacity: 0, transition: { duration: 0.2 } },
};

export const reducedCardVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { duration: 0.2 } },
};

// Helper for conditional reduced motion
export const getPageVariants = (shouldReduceMotion: boolean) => shouldReduceMotion ? reducedPageVariants : pageVariants;
export const getCardVariants = (shouldReduceMotion: boolean) => shouldReduceMotion ? reducedCardVariants : cardVariants;
export const getHoverProps = (shouldReduceMotion: boolean) => shouldReduceMotion ? {} : hoverCardProps;
export const getButtonProps = (shouldReduceMotion: boolean) => shouldReduceMotion ? {} : buttonProps;
