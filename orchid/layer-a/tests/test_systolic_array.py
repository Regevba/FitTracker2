"""U7 Systolic Array tests. Simplified behavioral model — cycle counting for matmul."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

def test_matmul_correct():
    from units.systolic_array import SystolicArray
    sa = SystolicArray(mesh_rows=8, mesh_cols=8)
    A = [[1, 2], [3, 4]]
    B = [[5, 6], [7, 8]]
    result = sa.matmul(A, B)
    assert result == [[19, 22], [43, 50]]

def test_cycle_count_scales_with_size():
    from units.systolic_array import SystolicArray
    sa = SystolicArray(mesh_rows=8, mesh_cols=8)
    small = [[1] * 4 for _ in range(4)]
    sa.matmul(small, small)
    cycles_small = sa.last_op_cycles
    large = [[1] * 16 for _ in range(16)]
    sa.matmul(large, large)
    cycles_large = sa.last_op_cycles
    assert cycles_large > cycles_small

def test_energy_estimate():
    from units.systolic_array import SystolicArray
    sa = SystolicArray(mesh_rows=8, mesh_cols=8)
    A = [[1] * 8 for _ in range(8)]
    sa.matmul(A, A)
    assert sa.last_op_energy_pj > 0
