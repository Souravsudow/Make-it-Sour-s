import { motion } from 'framer-motion';
import { Link } from '@remix-run/react';

export function Footer() {
  return (
    <motion.footer 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: 0.4, duration: 0.5 }}
      className="site-footer mt-16 py-8"
    >
      <div className="container mx-auto px-6 text-center text-gray-400">
        <p>
          No data is permanently stored on our servers. Read our{' '}
          <Link to="/privacy" className="text-primary hover:underline hover:text-primary/80">
            Privacy Policy
          </Link>
          . We're{' '}
          <a href="https://github.com/martin226/makeitjakes" className="text-primary hover:underline hover:text-primary/80" target="_blank" rel="noopener noreferrer">
            open-source
          </a>{' '}
          ❤️! By{' '}
          <a href="https://souravsiteee.netlify.app" className="text-primary hover:underline hover:text-primary/80" target="_blank" rel="noopener noreferrer">
            @_Sourav
          </a>
          {' '} &copy; {new Date().getFullYear()}.
        </p>
      </div>
    </motion.footer>
  );
}