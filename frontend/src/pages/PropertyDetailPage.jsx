import React from 'react';
import { useParams } from 'react-router-dom';

const PropertyDetailPage = () => {
  const { id } = useParams();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Property Details</h1>
        <p className="text-gray-600">Property ID: {id}</p>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <p className="text-gray-500">Property detail page - Coming soon!</p>
      </div>
    </div>
  );
};

export default PropertyDetailPage;