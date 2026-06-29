import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Barbero } from './barbero';

describe('Barbero', () => {
  let component: Barbero;
  let fixture: ComponentFixture<Barbero>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Barbero]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Barbero);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
