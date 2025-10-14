"use client";

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface RecordDetail {
  id: string;
  source: string;
  captured_at: string;
  processed_at?: string;
  fingerprint: string;
  raw_s3_key?: string;
  [key: string]: any;
}

export default function RecordDetailPage({ params }: { params: { id: string } }) {
  const [record, setRecord] = useState<RecordDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  const API_URL = process.env.NEXT_PUBLIC_API_URL || '';
  const API_KEY = process.env.NEXT_PUBLIC_API_KEY || '';

  useEffect(() => {
    fetchRecord();
  }, [params.id]);

  const fetchRecord = async () => {
    try {
      const headers: HeadersInit = {
        'Content-Type': 'application/json',
      };
      
      if (API_KEY) {
        headers['x-api-key'] = API_KEY;
      }
      
      const response = await fetch(`${API_URL}/records/${params.id}`, { headers });
      if (response.status === 404) {
        throw new Error('Record not found');
      }
      if (!response.ok) throw new Error('Failed to fetch record');
      
      const data = await response.json();
      setRecord(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl">Loading record...</div>
      </div>
    );
  }

  if (error || !record) {
    return (
      <div className="space-y-4">
        <button 
          onClick={() => router.back()}
          className="text-blue-600 hover:text-blue-800"
        >
          ← Back to Records
        </button>
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          <p className="font-bold">Error</p>
          <p>{error || 'Record not found'}</p>
        </div>
      </div>
    );
  }

  const coreFields = ['id', 'source', 'captured_at', 'processed_at', 'fingerprint', 'raw_s3_key'];
  const dataFields = Object.entries(record).filter(([key]) => !coreFields.includes(key));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <button 
          onClick={() => router.back()}
          className="text-blue-600 hover:text-blue-800 font-medium"
        >
          ← Back to Records
        </button>
      </div>

      <div>
        <h1 className="text-4xl font-bold mb-2">Record Detail</h1>
        <p className="text-gray-600">Complete information for this record</p>
      </div>

      {/* Core Information */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-2xl font-bold mb-4">Core Information</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm font-semibold text-gray-600">ID</label>
            <p className="font-mono text-sm break-all">{record.id}</p>
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-600">Source</label>
            <p>
              <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                record.source === 'jsonplaceholder' 
                  ? 'bg-blue-100 text-blue-800'
                  : 'bg-green-100 text-green-800'
              }`}>
                {record.source}
              </span>
            </p>
          </div>
          <div>
            <label className="text-sm font-semibold text-gray-600">Captured At</label>
            <p>{new Date(record.captured_at).toLocaleString()}</p>
          </div>
          {record.processed_at && (
            <div>
              <label className="text-sm font-semibold text-gray-600">Processed At</label>
              <p>{new Date(record.processed_at).toLocaleString()}</p>
            </div>
          )}
          <div>
            <label className="text-sm font-semibold text-gray-600">Fingerprint</label>
            <p className="font-mono text-sm">{record.fingerprint}</p>
          </div>
          {record.raw_s3_key && (
            <div className="md:col-span-2">
              <label className="text-sm font-semibold text-gray-600">Raw S3 Key</label>
              <p className="font-mono text-xs break-all text-gray-600">{record.raw_s3_key}</p>
            </div>
          )}
        </div>
      </div>

      {/* Data Fields */}
      {dataFields.length > 0 && (
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-2xl font-bold mb-4">Data Fields</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {dataFields.map(([key, value]) => (
              <div key={key}>
                <label className="text-sm font-semibold text-gray-600 capitalize">
                  {key.replace(/_/g, ' ')}
                </label>
                <p className="break-words">{String(value)}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Raw JSON */}
      <div className="bg-gray-900 rounded-lg shadow p-6 text-white">
        <h2 className="text-xl font-bold mb-4">Raw JSON</h2>
        <pre className="overflow-auto text-xs">
          {JSON.stringify(record, null, 2)}
        </pre>
      </div>
    </div>
  );
}

