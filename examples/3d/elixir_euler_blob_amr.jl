
using OrdinaryDiffEq
using Trixi

###############################################################################
# semidiscretization of the compressible Euler equations
gamma = 5/3
equations = CompressibleEulerEquations3D(gamma)

initial_condition = initial_condition_blob

surface_flux = flux_hllc
volume_flux  = flux_ranocha
solver = DGSEM(3, surface_flux, VolumeIntegralFluxDifferencing(volume_flux))

coordinates_min = (-20, -20, -20)
coordinates_max = ( 20,  20,  20)

refinement_patches = (
  (type="box", coordinates_min=(-20, -10, -10), coordinates_max=(-10, 10, 10)),
  (type="box", coordinates_min=(-20,  -5,  -5), coordinates_max=(-10,  5,  5)),
  (type="box", coordinates_min=(-17,  -2,  -2), coordinates_max=(-13,  2,  2)),
)
mesh = TreeMesh(coordinates_min, coordinates_max,
                initial_refinement_level=2,
                refinement_patches=refinement_patches,
                n_cells_max=100_000,)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver)


###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 2.5)
ode = semidiscretize(semi, tspan)

summary_callback = SummaryCallback()

amr_indicator = IndicatorLöhner(semi,
                                variable=density)
amr_controller = ControllerThreeLevel(semi, amr_indicator,
                                      base_level=1,
                                      med_level =0, med_threshold=0.1, # med_level = current level
                                      max_level =6, max_threshold=0.3)
amr_callback = AMRCallback(semi, amr_controller,
                           interval=3,
                           adapt_initial_condition=false,
                           adapt_initial_condition_only_refine=true)

stepsize_callback = StepsizeCallback(cfl=0.1)

save_solution = SaveSolutionCallback(interval=200,
                                     save_initial_solution=true,
                                     save_final_solution=true,
                                     solution_variables=:primitive)

analysis_interval = 200
alive_callback = AliveCallback(analysis_interval=analysis_interval)
analysis_callback = AnalysisCallback(semi, interval=analysis_interval)

callbacks = CallbackSet(summary_callback, amr_callback, stepsize_callback,
                        save_solution,
                        analysis_callback, alive_callback)


limiter! = PositivityPreservingLimiterZhangShu(thresholds=(1.0e-4, 1.0e-4),
                                               variables=(density, pressure))
stage_limiter! = limiter!
step_limiter!  = limiter!

###############################################################################
# run the simulation

sol = solve(ode, CarpenterKennedy2N54(stage_limiter!, step_limiter!, williamson_condition=false),
            dt=1.0, # solve needs some value here but it will be overwritten by the stepsize_callback
            save_everystep=false, callback=callbacks);
summary_callback() # print the timer summary
