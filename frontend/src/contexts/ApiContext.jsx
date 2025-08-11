import React, { createContext, useContext } from 'react';
import axios from 'axios';

const ApiContext = createContext({});

export const useApi = () => {
  const context = useContext(ApiContext);
  if (!context) {
    throw new Error('useApi must be used within an ApiProvider');
  }
  return context;
};

// Create axios instance
const createApiInstance = () => {
  const baseURL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1';
  
  const instance = axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      'Content-Type': 'application/json',
    },
  });

  // Request interceptor to add auth token
  instance.interceptors.request.use(
    (config) => {
      const token = localStorage.getItem('auth_token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    },
    (error) => {
      return Promise.reject(error);
    }
  );

  // Response interceptor to handle auth errors
  instance.interceptors.response.use(
    (response) => {
      return response;
    },
    async (error) => {
      const originalRequest = error.config;

      if (error.response?.status === 401 && !originalRequest._retry) {
        originalRequest._retry = true;

        try {
          const refreshToken = localStorage.getItem('refresh_token');
          if (refreshToken) {
            const response = await axios.post(`${baseURL}/auth/refresh`, {
              refreshToken
            });
            
            const { token } = response.data;
            localStorage.setItem('auth_token', token);
            
            // Retry original request with new token
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return instance(originalRequest);
          }
        } catch (refreshError) {
          // Refresh failed, redirect to login
          localStorage.removeItem('auth_token');
          localStorage.removeItem('refresh_token');
          localStorage.removeItem('user_data');
          window.location.href = '/login';
        }
      }

      return Promise.reject(error);
    }
  );

  return instance;
};

export const ApiProvider = ({ children }) => {
  const api = createApiInstance();

  // API methods
  const apiMethods = {
    // Auth
    auth: {
      login: (email, password) => api.post('/auth/login', { email, password }),
      logout: () => api.post('/auth/logout'),
      refresh: (refreshToken) => api.post('/auth/refresh', { refreshToken }),
      profile: () => api.get('/auth/profile'),
    },

    // Organizations
    organizations: {
      list: (params = {}) => api.get('/organizations', { params }),
      get: (id) => api.get(`/organizations/${id}`),
      stats: (id) => api.get(`/organizations/${id}/stats`),
    },

    // Properties
    properties: {
      list: (params = {}) => api.get('/properties', { params }),
      get: (id) => api.get(`/properties/${id}`),
      create: (data) => api.post('/properties', data),
      update: (id, data) => api.put(`/properties/${id}`, data),
      delete: (id) => api.delete(`/properties/${id}`),
    },

    // Work Logs
    workLogs: {
      list: (params = {}) => api.get('/work-logs', { params }),
      get: (id) => api.get(`/work-logs/${id}`),
      create: (data) => api.post('/work-logs', data),
      update: (id, data) => api.put(`/work-logs/${id}`, data),
      delete: (id) => api.delete(`/work-logs/${id}`),
    },

    // Documents
    documents: {
      list: (params = {}) => api.get('/documents', { params }),
      get: (id) => api.get(`/documents/${id}`),
      upload: (formData) => api.post('/documents', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      }),
      delete: (id) => api.delete(`/documents/${id}`),
    },

    // Invoices
    invoices: {
      list: (params = {}) => api.get('/invoices', { params }),
      get: (id) => api.get(`/invoices/${id}`),
      create: (data) => api.post('/invoices', data),
      update: (id, data) => api.put(`/invoices/${id}`, data),
      approve: (id) => api.patch(`/invoices/${id}/approve`),
      reject: (id) => api.patch(`/invoices/${id}/reject`),
    },

    // Reports
    reports: {
      workSummary: (params = {}) => api.get('/reports/work-summary', { params }),
      costs: (params = {}) => api.get('/reports/costs', { params }),
      maintenance: (params = {}) => api.get('/reports/maintenance-schedule', { params }),
      export: (type, params = {}) => api.get(`/reports/export/${type}`, { 
        params,
        responseType: 'blob'
      }),
    },

    // Generic CRUD methods
    get: (url, config) => api.get(url, config),
    post: (url, data, config) => api.post(url, data, config),
    put: (url, data, config) => api.put(url, data, config),
    patch: (url, data, config) => api.patch(url, data, config),
    delete: (url, config) => api.delete(url, config),
  };

  const value = {
    api: apiMethods,
    rawApi: api, // For direct axios usage if needed
  };

  return (
    <ApiContext.Provider value={value}>
      {children}
    </ApiContext.Provider>
  );
};