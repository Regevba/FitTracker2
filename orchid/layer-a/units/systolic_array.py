"""U7 — Systolic Array (Simplified Behavioral Model).

Weight-stationary systolic array for matmul.

Cycle model: ceil(M/mesh_rows) * ceil(N/mesh_cols) * K + pipeline_depth
"""
import math
from .types import CycleCount


class SystolicArray:
    """Behavioral model of a systolic array for dense matrix multiplication.

    Simplified cycle model assumes perfect data reuse and tiling:
    - Weight matrix B is distributed row-wise across the array
    - Input activations A stream in sequentially
    - Partial results accumulate at each PE
    - Total cycles = row_tiles * col_tiles * K + pipeline_depth
    """

    def __init__(self, mesh_rows: int = 8, mesh_cols: int = 8, pipeline_depth: int = 4):
        """Initialize the systolic array mesh.

        Args:
            mesh_rows: Number of rows in the PE grid (default 8)
            mesh_cols: Number of columns in the PE grid (default 8)
            pipeline_depth: Pipeline stages in the datapath (default 4)
        """
        self.mesh_rows = mesh_rows
        self.mesh_cols = mesh_cols
        self.pipeline_depth = pipeline_depth
        self.last_op_cycles = 0
        self.last_op_energy_pj = 0.0
        self._energy_per_mac_pj = 0.5  # picojoules per MAC

    def matmul(self, A, B):
        """Perform matrix multiplication A @ B with cycle counting.

        Args:
            A: M x K matrix (list of lists)
            B: K x N matrix (list of lists)

        Returns:
            Result matrix M x N (list of lists)
        """
        M = len(A)
        K = len(A[0]) if A else 0
        N = len(B[0]) if B else 0

        # Tile computation: how many tiles needed in M and N dimensions
        row_tiles = math.ceil(M / self.mesh_rows)
        col_tiles = math.ceil(N / self.mesh_cols)

        # Cycle model: each tile takes K cycles, plus pipeline startup
        self.last_op_cycles = row_tiles * col_tiles * K + self.pipeline_depth

        # Energy: total MACs * energy per MAC
        total_macs = M * N * K
        self.last_op_energy_pj = total_macs * self._energy_per_mac_pj

        # Compute the actual result
        result = [[0] * N for _ in range(M)]
        for i in range(M):
            for j in range(N):
                for k in range(K):
                    result[i][j] += A[i][k] * B[k][j]

        return result
