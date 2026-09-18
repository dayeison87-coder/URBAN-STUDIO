import { ComponentFixture, TestBed } from '@angular/core/testing';

import { BarberoComponent } from './barbero';

describe('BarberoComponent', () => {
  let component: BarberoComponent;
  let fixture: ComponentFixture<BarberoComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BarberoComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(BarberoComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
