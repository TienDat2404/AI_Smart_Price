import { useState, useEffect, useCallback } from 'react'

/**
 * useApi — generic hook để gọi API với loading / error / data state.
 *
 * @param {() => Promise<any>} fetchFn  - hàm async trả về data
 * @param {any[]} deps                  - dependencies để re-fetch
 * @param {any} initialData             - giá trị khởi tạo cho data
 *
 * @returns {{ data, loading, error, refetch }}
 *
 * @example
 * const { data, loading, error, refetch } = useApi(
 *   () => adminService.getOverview(),
 *   []
 * )
 */
export function useApi(fetchFn, deps = [], initialData = null) {
  const [data, setData]       = useState(initialData)
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState(null)

  const execute = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await fetchFn()
      setData(result)
    } catch (err) {
      setError(err.message ?? 'Lỗi không xác định')
    } finally {
      setLoading(false)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  useEffect(() => { execute() }, [execute])

  return { data, loading, error, refetch: execute }
}
