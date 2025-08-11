import React, { createContext, useContext, useEffect, useState } from 'react';
import { useApi } from './ApiContext';
import toast from 'react-hot-toast';

const AuthContext = createContext({});

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const { api } = useApi();

  // Load user from localStorage on mount
  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    const userData = localStorage.getItem('user_data');
    
    if (token && userData) {
      try {
        const parsedUser = JSON.parse(userData);
        setUser(parsedUser);
        // Verify token is still valid
        api.get('/auth/profile')
          .then((response) => {
            setUser(response.data.user);
          })
          .catch(() => {
            // Token is invalid, clear storage
            localStorage.removeItem('auth_token');
            localStorage.removeItem('user_data');
            setUser(null);
          })
          .finally(() => {
            setLoading(false);
          });
      } catch (error) {
        console.error('Error parsing user data:', error);
        localStorage.removeItem('auth_token');
        localStorage.removeItem('user_data');
        setLoading(false);
      }
    } else {
      setLoading(false);
    }
  }, [api]);

  const login = async (email, password) => {
    try {
      const response = await api.post('/auth/login', {
        email,
        password
      });

      const { user: userData, token } = response.data;
      
      // Store in localStorage
      localStorage.setItem('auth_token', token);
      localStorage.setItem('user_data', JSON.stringify(userData));
      
      setUser(userData);
      
      toast.success(`Welcome back, ${userData.firstName}!`);
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Login failed';
      toast.error(message);
      return { success: false, error: message };
    }
  };

  const logout = async () => {
    try {
      // Call logout endpoint to invalidate session on server
      await api.post('/auth/logout');
      toast.success('Logged out successfully');
    } catch (error) {
      console.error('Logout error:', error);
      // Still show success message as local logout always works
      toast.success('Logged out successfully');
    } finally {
      // Always clear local state and storage
      localStorage.removeItem('auth_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user_data');
      
      // Clear any cached data
      sessionStorage.clear();
      
      // Reset user state
      setUser(null);
      
      // Optional: Clear any other app-specific storage
      try {
        // Clear any cached API responses
        if ('caches' in window) {
          caches.keys().then(names => {
            names.forEach(name => {
              if (name.includes('api-cache')) {
                caches.delete(name);
              }
            });
          });
        }
      } catch (cacheError) {
        console.debug('Cache cleanup error (non-critical):', cacheError);
      }
    }
  };

  const refreshToken = async () => {
    try {
      const refreshToken = localStorage.getItem('refresh_token');
      if (!refreshToken) {
        throw new Error('No refresh token available');
      }

      const response = await api.post('/auth/refresh', {
        refreshToken
      });

      const { token } = response.data;
      localStorage.setItem('auth_token', token);
      
      return token;
    } catch (error) {
      console.error('Token refresh failed:', error);
      logout();
      throw error;
    }
  };

  const hasPermission = (permission) => {
    if (!user || !user.permissions) return false;
    
    return user.permissions.some(p => 
      p === permission || 
      p === '*' || 
      (p.endsWith('*') && permission.startsWith(p.slice(0, -1)))
    );
  };

  const hasRole = (role) => {
    if (!user) return false;
    return user.role === role;
  };

  const canAccess = (requiredPermissions = [], requiredRoles = []) => {
    if (requiredPermissions.length === 0 && requiredRoles.length === 0) {
      return true; // No restrictions
    }

    // Check roles
    if (requiredRoles.length > 0 && !requiredRoles.some(role => hasRole(role))) {
      return false;
    }

    // Check permissions
    if (requiredPermissions.length > 0 && !requiredPermissions.some(permission => hasPermission(permission))) {
      return false;
    }

    return true;
  };

  const value = {
    user,
    loading,
    login,
    logout,
    refreshToken,
    hasPermission,
    hasRole,
    canAccess,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};