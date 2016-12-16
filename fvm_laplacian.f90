subroutine fvm_laplacian(mu,phi)
!  
!******************************************************************************
!
!     Fills matrix with coefficients representing implicit FVM discretization 
!     of negative Laplacian operator: -div(mu*grad(phi)).
!
!     System of linear equations is written as:
!     $ a_p^{(i)}*\phi_p^(i)-\sum_{j=1}^{nb} a_j^{(i)}*\phi_j^(i) = b_p{(i)}, i=1,ncells $
!
!******************************************************************************
!
  use types
  use parameters
  use geometry
  use sparse_matrix

  implicit none

  real(dp), dimension(numTotal), intent(in) :: mu,phi

  !
  ! Local variables
  !

  integer :: i, k, ijp, ijn, ijb, iface
  real(dp) :: cap, can
  real(dp) :: are,dpw


  ! Initialize matrix array
  a(:) = 0.0_dp

  ! > Assemble Laplacian system matrix

  ! Internal faces:
  do i = 1,numInnerFaces

    ijp = owner(i)
    ijn = neighbour(i)

    call facefluxlaplacian(ijp, ijn, arx(ijp), ary(ijp), arz(ijp), facint(i), mu, cap, can)

    ! > Off-diagonal elements:

    ! (icell,jcell) matrix element:
    k = icell_jcell_csr_value_index(i)
    a(k) = can

    ! (jcell,icell) matrix element:
    k = jcell_icell_csr_value_index(i)
    a(k) = cap

    ! > Elements on main diagonal:

    ! (icell,icell) main diagonal element
    k = diag(ijp)
    a(k) = a(k) - can

    ! (jcell,jcell) main diagonal element
    k = diag(ijn)
    a(k) = a(k) - cap

  end do


  ! o- and c-grid cuts
  do i=1,noc

    iface = iOCFacesStart+i
    ijp=ijl(i)
    ijn=ijr(i)

    call facefluxlaplacian(ijp, ijn, arx(iface), ary(iface), arz(iface), foc(i), mu, al(i), ar(i))
    
    ! > Elements on main diagonal:

    ! (icell,icell) main diagonal element
    k = diag(ijp)
    a(k) = a(k) - ar(i)

    ! (jcell,jcell) main diagonal element
    k = diag(ijn)
    a(k) = a(k) - al(i)

  end do


!.....Modify matrix coefficients to reflect presence of Boundary Conditions in PDE problem.

  ! Contribution from inlet boundaries
  do i=1,ninl
    iface = iInletFacesStart+i
    ijp = owner(iface)
    ijb = iInletStart+i

    k=diag(ijp)
    are = sqrt(arx(iface)**2+ary(iface)**2+arz(iface)**2)
    dpw = sqrt( (xc(ijp)-xf(iface))**2 + (yc(ijp)-yf(iface))**2 + (zc(ijp)-zf(iface))**2 )

    a(k) = a(k) - mu(ijp)*are/dpw !..or mu_wall*are/dpw;  
    su(ijp) = su(ijp) + a(k)*phi(ijb)

  end do

  ! Contribution from outlet boundaries
  do i=1,nout
    iface = iOutletFacesStart+i
    ijp = owner(iface)
    ijb = iOutletStart+i

    k=diag(ijp)
    are = sqrt(arx(iface)**2+ary(iface)**2+arz(iface)**2)
    dpw = sqrt( (xc(ijp)-xf(iface))**2 + (yc(ijp)-yf(iface))**2 + (zc(ijp)-zf(iface))**2 )

    a(k) = a(k) - mu(ijp)*are/dpw !..or mu_wall*are/dpw;  
    su(ijp) = su(ijp) + a(k)*phi(ijb)

  end do

  ! Contribution from symmetry boundaries
  do i=1,nsym
    ijp = owner(iSymmetryFacesStart+i)
    ijb = iSymmetryStart+i

    k=diag(ijp)

    a(k) = a(k) - mu(ijp)*srds(i)  
    su(ijp) = su(ijp) + a(k)*phi(ijb)

  end do

  ! Contribution from wall boundaries
  do i=1,nwal
    ijp = owner(iWallFacesStart+i)
    ijb = iWallStart+i

    k=diag(ijp)

    a(k) = a(k) - mu(ijp)*srdw(i)  
    su(ijp) = su(ijp) + a(k)*phi(ijb)
    
  end do

  ! Contribution from pressure outlet boundaries
  do i=1,npru
    ijp = owner(iPressOutletFacesStart+i)
    ijb = iPressOutletStart+i
  end do


end subroutine





!***********************************************************************
!
subroutine facefluxlaplacian(ijp, ijn, arx, ary, arz, lambda, mu, cap, can)
!
!***********************************************************************
!
  use types
  use parameters
  use geometry, only: numTotal,xc,yc,zc

  implicit none

  integer, intent(in) :: ijp, ijn
  real(dp), intent(in) :: arx, ary, arz
  real(dp), intent(in) :: lambda
  real(dp), dimension(numTotal), intent(in) :: mu
  real(dp), intent(inout) :: cap, can

  ! Local variables
  real(dp) :: fxn, fxp
  real(dp) :: are
  real(dp) :: xpn,ypn,zpn,smdpn,sfdpnr
  real(dp) :: nxx,nyy,nzz


  ! > Geometry:

  ! Face interpolation factor
  fxn=lambda 
  fxp=1.0d0-lambda

  ! Distance vector between cell centers
  xpn=xc(ijn)-xc(ijp)
  ypn=yc(ijn)-yc(ijp)
  zpn=zc(ijn)-zc(ijp)

  ! cell face area
  are=sqrt(arx**2+ary**2+arz**2)

  ! Unit vectors of the normal
  nxx=arx/are
  nyy=ary/are
  nzz=arz/are

  sfdpnr=1./(arx*xpn*nxx+ary*ypn*nyy+arz*zpn*nzz)
  smdpn = (arx*arx+ary*ary+arz*arz)*sfdpnr
!.....Coefficients of discretized Laplace equation
  cap = (fxp*mu(ijp)+fxn*mu(ijn))*smdpn
  can = cap

end subroutine
